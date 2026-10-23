// constructionLayoutViewer.js
import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent }   from 'lightning/platformShowToastEvent';
import getConstructionPackages from '@salesforce/apex/ConstructionLayoutController.getConstructionPackages';
import getLayoutData           from '@salesforce/apex/ConstructionLayoutController.getLayoutData';

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────
const PADDING       = 60;   // canvas inset padding (px in engineering space)
const MIN_ZOOM      = 0.05;
const MAX_ZOOM      = 20;
const ZOOM_FACTOR   = 1.18;
const PILE_RADIUS   = 5;    // base pile radius in engineering units
const PED_HALF      = 6;    // pedestal diamond half-size

// ─────────────────────────────────────────────────────────────────────────────
export default class ConstructionLayoutViewer extends NavigationMixin(LightningElement) {

    // ── State ──────────────────────────────────────────────────────────
    @track isLoading            = false;
    @track hasError             = false;
    @track errorMessage         = '';
    @track packageOptions       = [];
    @track selectedPackageId    = '';
    @track selectedPackageName  = '';
    @track selectedProjectName  = '';
    @track selectedPackageType  = '';
    @track lastRefreshed        = '';

    // Raw data
    @track _piles     = [];
    @track _rafts     = [];
    @track _pedestals = [];

    // Filters
    @track showPiles     = true;
    @track showRafts     = true;
    @track showPedestals = true;
    @track selectedStatus = '';

    // Selection
    @track selectedStructure  = null;
    @track selectedType       = '';  // 'pile' | 'raft' | 'pedestal'

    // Viewport / pan / zoom
    @track zoom      = 1;
    @track panX      = 0;
    @track panY      = 0;
    _isPanning       = false;
    _panStartX       = 0;
    _panStartY       = 0;
    _bounds          = null;  // { minX, maxX, minY, maxY, W, H }
    _canvasW         = 800;
    _canvasH         = 600;
    _fitZoom         = 1;
    _fitPanX         = 0;
    _fitPanY         = 0;

    // ── Wire: package list ─────────────────────────────────────────────
    @wire(getConstructionPackages)
    wiredPackages({ data, error }) {
        if (data) {
            this.packageOptions = [
                { label: '— All Packages —', value: '' },
                ...data.map(p => ({
                    label: p.label,
                    value: p.id
                }))
            ];
        } else if (error) {
            this._showError('Failed to load packages: ' + this._extractMessage(error));
        }
    }

    // ── Lifecycle ──────────────────────────────────────────────────────
    connectedCallback() {
        // No auto-load; wait for package selection
    }

    renderedCallback() {
        this._measureCanvas();
    }

    // ── Getters: Counts ────────────────────────────────────────────────
    get pileCount()     { return this._filteredPiles.length; }
    get raftCount()     { return this._filteredRafts.length; }
    get pedestalCount() { return this._filteredPedestals.length; }

    get validCoordCount() {
        const pOk  = this._filteredPiles.filter(p => p.hasCoordinates).length;
        const rOk  = this._filteredRafts.filter(r => r.hasGeometry).length;
        const pdOk = this._filteredPedestals.filter(pd => pd.hasCoordinates).length;
        return pOk + rOk + pdOk;
    }

    get missingCoordCount() {
        const total = this.pileCount + this.raftCount + this.pedestalCount;
        return total - this.validCoordCount;
    }

    // ── Getters: UI states ─────────────────────────────────────────────
    get showEmptyState() {
        return !this.isLoading && !this.selectedPackageId;
    }

    get showNoGeometry() {
        if (this.isLoading || !this.selectedPackageId) return false;
        return this.validCoordCount === 0;
    }

    get showCanvas() {
        return !this.isLoading && !!this.selectedPackageId && this.validCoordCount > 0;
    }

    get hasSelectedStructure() { return !!this.selectedStructure; }

    get hasDataQualityIssues() {
        return !!this.selectedPackageId && this.missingCoordCount > 0;
    }

    get dataQualitySummary() {
        const pBad  = this._filteredPiles.filter(p => !p.hasCoordinates).length;
        const rBad  = this._filteredRafts.filter(r => !r.hasGeometry).length;
        const pdBad = this._filteredPedestals.filter(pd => !pd.hasCoordinates).length;
        const parts = [];
        if (pBad  > 0) parts.push(`${pBad} pile${pBad  > 1 ? 's' : ''} missing coordinates`);
        if (rBad  > 0) parts.push(`${rBad} raft${rBad  > 1 ? 's' : ''} without valid geometry`);
        if (pdBad > 0) parts.push(`${pdBad} pedestal${pdBad > 1 ? 's' : ''} missing coordinates`);
        return parts.join(' · ') + ' — not shown in canvas.';
    }

    // ── Getters: Button CSS ────────────────────────────────────────────
    get pileBtnClass()     { return `clv-toggle-btn clv-toggle-pile${this.showPiles ? ' clv-toggle-active' : ''}`; }
    get raftBtnClass()     { return `clv-toggle-btn clv-toggle-raft${this.showRafts ? ' clv-toggle-active' : ''}`; }
    get pedestalBtnClass() { return `clv-toggle-btn clv-toggle-pedestal${this.showPedestals ? ' clv-toggle-active' : ''}`; }

    // ── Getters: Status options (combined from all 3 objects) ──────────
    get statusOptions() {
        const opts = new Set();
        this._piles.forEach(p => { if (p.status) opts.add(p.status); });
        this._rafts.forEach(r => { if (r.status) opts.add(r.status); });
        this._pedestals.forEach(pd => { if (pd.status) opts.add(pd.status); });
        const list = [{ label: 'All Statuses', value: '' }];
        [...opts].sort().forEach(s => list.push({ label: s, value: s }));
        return list;
    }

    // ── Getters: Filtered datasets ─────────────────────────────────────
    get _filteredPiles() {
        return this._piles.filter(p =>
            !this.selectedStatus || p.status === this.selectedStatus
        );
    }
    get _filteredRafts() {
        return this._rafts.filter(r =>
            !this.selectedStatus || r.status === this.selectedStatus
        );
    }
    get _filteredPedestals() {
        return this._pedestals.filter(pd =>
            !this.selectedStatus || pd.status === this.selectedStatus
        );
    }

    // ── Getters: SVG Transform ─────────────────────────────────────────
    get svgTransform() {
        return `translate(${this.panX},${this.panY}) scale(${this.zoom})`;
    }

    get zoomPercent() { return Math.round(this.zoom * 100); }

    // ── Getters: Grid lines ────────────────────────────────────────────
    get gridMinorSize() { return Math.max(5, 50 / this.zoom); }
    get gridMajorSize() { return this.gridMinorSize * 5; }
    get gridMinorPath() { const s = this.gridMinorSize; return `M ${s} 0 L 0 0 0 ${s}`; }
    get gridMajorPath() { const s = this.gridMajorSize; return `M ${s} 0 L 0 0 0 ${s}`; }
    get gridOffsetX()   { return this.panX % this.gridMajorSize; }
    get gridOffsetY()   { return this.panY % this.gridMajorSize; }

    // ── Getters: Pile radius (screen-stable) ───────────────────────────
    get pileRadius() { return PILE_RADIUS; }

    // ── Getters: Visible SVG structures ───────────────────────────────
    get visiblePiles() {
        if (!this._bounds) return [];
        const b = this._bounds;
        return this._filteredPiles
            .filter(p => p.hasCoordinates)
            .map(p => {
                const svgX = this._toSvgX(Number(p.x), b);
                const svgY = this._toSvgY(Number(p.y), b);
                const isSelected = this.selectedStructure && this.selectedStructure.id === p.id;
                return {
                    id:           p.id,
                    svgX,
                    svgY,
                    labelY:       svgY - PILE_RADIUS - 3,
                    displayLabel: p.pileIdNumber || p.name,
                    circleClass:  isSelected ? 'clv-pile-circle clv-pile-selected' : 'clv-pile-circle',
                    labelClass:   isSelected ? 'clv-svg-label clv-label-selected' : 'clv-svg-label clv-label-pile'
                };
            });
    }

    get visibleRafts() {
        if (!this._bounds) return [];
        const b = this._bounds;
        return this._filteredRafts
            .filter(r => r.hasGeometry)
            .map(r => {
                const pts = this._parseRaftPoints(r.coordinatesJson, b);
                const isSelected = this.selectedStructure && this.selectedStructure.id === r.id;
                const centroid = this._centroid(pts);
                return {
                    id:           r.id,
                    svgPoints:    pts.map(p => `${p.x},${p.y}`).join(' '),
                    labelX:       centroid.x,
                    labelY:       centroid.y,
                    displayLabel: r.raftNumber || r.name,
                    polygonClass: isSelected ? 'clv-raft-polygon clv-raft-selected' : 'clv-raft-polygon',
                    labelClass:   isSelected ? 'clv-svg-label clv-label-selected' : 'clv-svg-label clv-label-raft'
                };
            });
    }

    get visiblePedestals() {
        if (!this._bounds) return [];
        const b = this._bounds;
        const half = PED_HALF;
        return this._filteredPedestals
            .filter(pd => pd.hasCoordinates)
            .map(pd => {
                const svgX = this._toSvgX(Number(pd.x), b);
                const svgY = this._toSvgY(Number(pd.y), b);
                const isSelected = this.selectedStructure && this.selectedStructure.id === pd.id;
                const diamond = `${svgX},${svgY - half} ${svgX + half},${svgY} ${svgX},${svgY + half} ${svgX - half},${svgY}`;
                return {
                    id:           pd.id,
                    svgX,
                    svgY,
                    labelY:       svgY - half - 3,
                    svgDiamond:   diamond,
                    displayLabel: pd.gridReference || pd.name,
                    polygonClass: isSelected ? 'clv-ped-diamond clv-ped-selected' : 'clv-ped-diamond',
                    labelClass:   isSelected ? 'clv-svg-label clv-label-selected' : 'clv-svg-label clv-label-ped'
                };
            });
    }

    // ── Getters: Selected structure detail ─────────────────────────────
    get selectedIcon() {
        switch (this.selectedType) {
            case 'pile':     return 'utility:record';
            case 'raft':     return 'utility:table';
            case 'pedestal': return 'utility:connected_apps';
            default:         return 'utility:info';
        }
    }

    get selectedFields() {
        if (!this.selectedStructure) return [];
        const s = this.selectedStructure;
        if (this.selectedType === 'pile') {
            return [
                { key: 'pid',    label: 'Pile ID',          value: s.pileIdNumber   || '—' },
                { key: 'stat',   label: 'Status',           value: s.status         || '—' },
                { key: 'diam',   label: 'Diameter',         value: s.diameterMm ? `${s.diameterMm} mm` : '—' },
                { key: 'depth',  label: 'Founding Depth',   value: s.foundingDepthM ? `${s.foundingDepthM} m` : '—' },
                { key: 'grade',  label: 'Concrete Grade',   value: s.concreteGrade  || '—' },
                { key: 'xcoord', label: 'X Coordinate',     value: s.x != null ? `${s.x}` : '—' },
                { key: 'ycoord', label: 'Y Coordinate',     value: s.y != null ? `${s.y}` : '—' }
            ];
        }
        if (this.selectedType === 'raft') {
            return [
                { key: 'rnum',  label: 'Raft Number',     value: s.raftNumber    || '—' },
                { key: 'stat',  label: 'Status',          value: s.status        || '—' },
                { key: 'len',   label: 'Length',          value: s.lengthM ? `${s.lengthM} m` : '—' },
                { key: 'wid',   label: 'Width',           value: s.widthM  ? `${s.widthM} m`  : '—' },
                { key: 'dep',   label: 'Depth',           value: s.depthM  ? `${s.depthM} m`  : '—' },
                { key: 'grade', label: 'Concrete Grade',  value: s.concreteGrade || '—' },
                { key: 'crns',  label: 'Corners',         value: s.numberOfCorners ? `${s.numberOfCorners}` : '—' }
            ];
        }
        if (this.selectedType === 'pedestal') {
            return [
                { key: 'grid',  label: 'Grid Reference',  value: s.gridReference        || '—' },
                { key: 'stat',  label: 'Status',          value: s.status               || '—' },
                { key: 'sec',   label: 'Cross Section',   value: s.crossSection         || '—' },
                { key: 'hgt',   label: 'Height',          value: s.heightM ? `${s.heightM} m` : '—' },
                { key: 'ab',    label: 'Anchor Bolts',    value: s.anchorBoltInspection || '—' },
                { key: 'xcoord',label: 'X Coordinate',    value: s.x != null ? `${s.x}` : '—' },
                { key: 'ycoord',label: 'Y Coordinate',    value: s.y != null ? `${s.y}` : '—' }
            ];
        }
        return [];
    }

    // ── Event Handlers: Filters ────────────────────────────────────────
    handlePackageChange(event) {
        this.selectedPackageId = event.detail.value;
        this.selectedStructure = null;
        this._loadLayoutData();
    }

    handleStatusChange(event) {
        this.selectedStatus = event.detail.value;
        this._recompute();
    }

    togglePiles()     { this.showPiles     = !this.showPiles;     this._recompute(); }
    toggleRafts()     { this.showRafts     = !this.showRafts;     this._recompute(); }
    togglePedestals() { this.showPedestals = !this.showPedestals; this._recompute(); }

    handleRefresh() {
        this._loadLayoutData(true);
    }

    // ── Event Handlers: Viewport Controls ─────────────────────────────
    handleFitView()    { this._applyFitView(); }
    handleZoomIn()     { this._applyZoom(ZOOM_FACTOR); }
    handleZoomOut()    { this._applyZoom(1 / ZOOM_FACTOR); }
    handleResetView()  { this._applyFitView(); }

    onSvgMouseDown(event) {
        if (event.button !== 0) return;
        this._isPanning = true;
        this._panStartX = event.clientX - this.panX;
        this._panStartY = event.clientY - this.panY;
        event.preventDefault();
    }

    onSvgMouseMove(event) {
        if (!this._isPanning) return;
        this.panX = event.clientX - this._panStartX;
        this.panY = event.clientY - this._panStartY;
    }

    onSvgMouseUp() { this._isPanning = false; }

    onSvgWheel(event) {
        event.preventDefault();
        const factor = event.deltaY < 0 ? ZOOM_FACTOR : 1 / ZOOM_FACTOR;
        const rect   = event.currentTarget.getBoundingClientRect();
        const mx     = event.clientX - rect.left;
        const my     = event.clientY - rect.top;
        const newZoom = Math.max(MIN_ZOOM, Math.min(MAX_ZOOM, this.zoom * factor));
        this.panX = mx - (mx - this.panX) * (newZoom / this.zoom);
        this.panY = my - (my - this.panY) * (newZoom / this.zoom);
        this.zoom = newZoom;
    }

    // ── Event Handlers: Structure Selection ───────────────────────────
    onStructureClick(event) {
        const id   = event.currentTarget.dataset.id;
        const type = event.currentTarget.dataset.type;
        if (this.selectedStructure && this.selectedStructure.id === id) {
            this.clearSelection();
            return;
        }
        let found = null;
        if (type === 'pile') {
            found = this._piles.find(p => p.id === id);
            this.selectedType = 'pile';
        } else if (type === 'raft') {
            found = this._rafts.find(r => r.id === id);
            this.selectedType = 'raft';
        } else if (type === 'pedestal') {
            found = this._pedestals.find(pd => pd.id === id);
            this.selectedType = 'pedestal';
        }
        this.selectedStructure = found || null;
    }

    clearSelection() {
        this.selectedStructure = null;
        this.selectedType = '';
    }

    openSelectedRecord() {
        if (!this.selectedStructure) return;
        const objApiMap = {
            pile:     'Pile__c',
            raft:     'Raft__c',
            pedestal: 'Pedestal__c'
        };
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId:   this.selectedStructure.id,
                objectApiName: objApiMap[this.selectedType] || '',
                actionName: 'view'
            }
        });
    }

    // ── Private: Data Loading ──────────────────────────────────────────
    _loadLayoutData(forceRefresh = false) {
        if (!this.selectedPackageId) {
            this._piles     = [];
            this._rafts     = [];
            this._pedestals = [];
            this.selectedPackageName = '';
            this.selectedProjectName = '';
            this._bounds = null;
            return;
        }
        this.isLoading  = true;
        this.hasError   = false;

        // Bypass wire cache by calling imperatively
        getLayoutData({ packageId: this.selectedPackageId })
            .then(result => {
                this._piles            = result.piles     || [];
                this._rafts            = result.rafts     || [];
                this._pedestals        = result.pedestals || [];
                this.selectedPackageName = result.packageName || '';
                this.selectedProjectName = result.projectName || '';
                this.selectedPackageType = result.packageType || '';
                this._computeBounds();
                this._applyFitView();
                const now = new Date();
                this.lastRefreshed = now.toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' });
            })
            .catch(err => {
                this._showError('Failed to load layout data: ' + this._extractMessage(err));
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // ── Private: Bounds & Coordinate Mapping ──────────────────────────
    _computeBounds() {
        this._measureCanvas();
        const xs = [];
        const ys = [];

        this._piles.filter(p => p.hasCoordinates).forEach(p => {
            xs.push(Number(p.x));
            ys.push(Number(p.y));
        });

        this._pedestals.filter(pd => pd.hasCoordinates).forEach(pd => {
            xs.push(Number(pd.x));
            ys.push(Number(pd.y));
        });

        this._rafts.filter(r => r.hasGeometry).forEach(r => {
            try {
                const pts = JSON.parse(r.coordinatesJson);
                pts.forEach(pt => {
                    if (pt.x != null && pt.y != null) {
                        xs.push(Number(pt.x));
                        ys.push(Number(pt.y));
                    }
                });
            } catch (e) { /* skip */ }
        });

        if (xs.length === 0) {
            this._bounds = null;
            return;
        }

        const minX = Math.min(...xs);
        const maxX = Math.max(...xs);
        const minY = Math.min(...ys);
        const maxY = Math.max(...ys);
        const W    = Math.max(maxX - minX, 1);
        const H    = Math.max(maxY - minY, 1);

        const usableW = Math.max(100, this._canvasW - 2 * PADDING);
        const usableH = Math.max(100, this._canvasH - 2 * PADDING);
        // Preserve 1:1 engineering aspect ratio (scaleX === scaleY)
        const uniformScale = Math.min(usableW / W, usableH / H);
        const offsetX = PADDING + (usableW - W * uniformScale) / 2;
        const offsetY = PADDING + (usableH - H * uniformScale) / 2;

        this._bounds = { minX, maxX, minY, maxY, W, H, uniformScale, offsetX, offsetY };
    }

    _toSvgX(engX, b) {
        return b.offsetX + (engX - b.minX) * b.uniformScale;
    }

    _toSvgY(engY, b) {
        // Invert Y so larger engineering Y = higher on screen (towards top)
        return b.offsetY + (b.maxY - engY) * b.uniformScale;
    }

    _parseRaftPoints(jsonStr, b) {
        try {
            const parsed = JSON.parse(jsonStr);
            const sorted = [...parsed].sort((a, b) => a.sequence - b.sequence);
            return sorted.map(pt => ({
                x: this._toSvgX(Number(pt.x), b),
                y: this._toSvgY(Number(pt.y), b)
            }));
        } catch (e) {
            return [];
        }
    }

    _centroid(pts) {
        if (!pts || pts.length === 0) return { x: 0, y: 0 };
        const cx = pts.reduce((s, p) => s + p.x, 0) / pts.length;
        const cy = pts.reduce((s, p) => s + p.y, 0) / pts.length;
        return { x: cx, y: cy };
    }

    // ── Private: Zoom / Pan ────────────────────────────────────────────
    _measureCanvas() {
        const wrapper = this.template.querySelector('.clv-svg-wrapper');
        if (wrapper && wrapper.clientWidth > 0 && wrapper.clientHeight > 0) {
            this._canvasW = wrapper.clientWidth;
            this._canvasH = wrapper.clientHeight;
        }
    }

    _applyFitView() {
        this._measureCanvas();
        this.zoom = 1;
        this.panX = 0;
        this.panY = 0;
        this._fitZoom = 1;
        this._fitPanX = 0;
        this._fitPanY = 0;
    }

    _applyZoom(factor) {
        const newZoom = Math.max(MIN_ZOOM, Math.min(MAX_ZOOM, this.zoom * factor));
        const cx = this._canvasW / 2;
        const cy = this._canvasH / 2;
        this.panX = cx - (cx - this.panX) * (newZoom / this.zoom);
        this.panY = cy - (cy - this.panY) * (newZoom / this.zoom);
        this.zoom = newZoom;
    }

    _recompute() {
        this._computeBounds();
        // If bounds changed significantly, refit
        this._applyFitView();
    }

    // ── Private: Helpers ───────────────────────────────────────────────
    _showError(msg) {
        this.hasError    = true;
        this.errorMessage = msg;
        this.dispatchEvent(new ShowToastEvent({
            title:   'Error',
            message: msg,
            variant: 'error'
        }));
    }

    _extractMessage(error) {
        if (!error) return 'Unknown error';
        if (typeof error.body?.message === 'string') return error.body.message;
        if (typeof error.message === 'string') return error.message;
        return JSON.stringify(error);
    }
}
