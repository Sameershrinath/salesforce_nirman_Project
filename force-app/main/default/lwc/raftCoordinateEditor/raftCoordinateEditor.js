import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getRaftGeometry from '@salesforce/apex/RaftCoordinateController.getRaftGeometry';
import saveRaftGeometry from '@salesforce/apex/RaftCoordinateController.saveRaftGeometry';

const MIN_CORNERS = 3;
const MAX_CORNERS = 20;
const CANVAS_WIDTH = 560;
const CANVAS_HEIGHT = 380;
const CANVAS_PADDING = 45;

export default class RaftCoordinateEditor extends LightningElement {
    @api recordId;

    @track points = [];
    @track savedPoints = [];
    @track numberOfCorners = 4;
    @track savedNumberOfCorners = 4;

    isLoading = false;
    isSaving = false;
    isReadOnly = false;

    raftTitle = 'Raft Foundation Geometry';
    raftNumber = '';
    packageName = '';

    errorMessage = '';
    successMessage = '';

    // Modal state for corner reduction
    showReductionWarningModal = false;
    pendingCornerCount = null;

    connectedCallback() {
        if (this.recordId) {
            this.loadGeometry();
        }
    }

    get cornerCountString() {
        return String(this.numberOfCorners);
    }

    get currentCornerCount() {
        return this.numberOfCorners;
    }

    get cornerOptions() {
        const options = [];
        for (let i = MIN_CORNERS; i <= MAX_CORNERS; i++) {
            options.push({ label: `${i} Corners`, value: String(i) });
        }
        return options;
    }

    get isSaveDisabled() {
        return this.isLoading || this.isSaving || this.isReadOnly || !this.hasValidGeometry;
    }

    get isRevertDisabled() {
        return this.isLoading || this.isSaving || !this.hasUnsavedChanges;
    }

    get hasUnsavedChanges() {
        if (this.numberOfCorners !== this.savedNumberOfCorners) {
            return true;
        }
        if (this.points.length !== this.savedPoints.length) {
            return true;
        }
        for (let i = 0; i < this.points.length; i++) {
            const p = this.points[i];
            const sp = this.savedPoints[i];
            if (!sp || p.x !== sp.x || p.y !== sp.y) {
                return true;
            }
        }
        return false;
    }

    get hasValidGeometry() {
        if (!this.points || this.points.length !== this.numberOfCorners || this.numberOfCorners < MIN_CORNERS) {
            return false;
        }
        return this.points.every(pt => pt.x !== null && pt.x !== undefined && pt.x !== '' &&
                                       pt.y !== null && pt.y !== undefined && pt.y !== '' &&
                                       !isNaN(Number(pt.x)) && !isNaN(Number(pt.y)));
    }

    get pointsToDiscardDescription() {
        if (this.pendingCornerCount === null || this.pendingCornerCount >= this.numberOfCorners) {
            return '';
        }
        const discarded = [];
        for (let i = this.pendingCornerCount + 1; i <= this.numberOfCorners; i++) {
            discarded.push(i);
        }
        return discarded.join(', ');
    }

    get svgViewBox() {
        return `0 0 ${CANVAS_WIDTH} ${CANVAS_HEIGHT}`;
    }

    get svgVertices() {
        if (!this.hasValidGeometry) {
            return [];
        }

        const numericPoints = this.points.map(p => ({
            sequence: p.sequence,
            x: Number(p.x),
            y: Number(p.y)
        }));

        const xs = numericPoints.map(p => p.x);
        const ys = numericPoints.map(p => p.y);
        const minX = Math.min(...xs);
        const maxX = Math.max(...xs);
        const minY = Math.min(...ys);
        const maxY = Math.max(...ys);

        const rangeX = (maxX - minX) === 0 ? 1 : (maxX - minX);
        const rangeY = (maxY - minY) === 0 ? 1 : (maxY - minY);

        const drawWidth = CANVAS_WIDTH - (CANVAS_PADDING * 2);
        const drawHeight = CANVAS_HEIGHT - (CANVAS_PADDING * 2);

        // Preserve aspect ratio
        const scale = Math.min(drawWidth / rangeX, drawHeight / rangeY);
        const offsetX = CANVAS_PADDING + (drawWidth - (rangeX * scale)) / 2;
        const offsetY = CANVAS_PADDING + (drawHeight - (rangeY * scale)) / 2;

        return numericPoints.map(pt => {
            // Invert Y axis for engineering Cartesian space
            const svgX = offsetX + ((pt.x - minX) * scale);
            const svgY = (CANVAS_HEIGHT - offsetY) - ((pt.y - minY) * scale);

            return {
                sequence: pt.sequence,
                rawX: pt.x,
                rawY: pt.y,
                svgX: svgX.toFixed(2),
                svgY: svgY.toFixed(2),
                labelX: svgX.toFixed(2),
                labelY: (svgY - 10).toFixed(2),
                circleClass: pt.sequence === 1 ? 'vertex-point start-node' : 'vertex-point'
            };
        });
    }

    get svgPointsString() {
        return this.svgVertices.map(v => `${v.svgX},${v.svgY}`).join(' ');
    }

    get geometryMetrics() {
        if (!this.hasValidGeometry) {
            return { width: '0.00', height: '0.00', perimeter: '0.00' };
        }

        const pts = this.points.map(p => ({ x: Number(p.x), y: Number(p.y) }));
        const xs = pts.map(p => p.x);
        const ys = pts.map(p => p.y);
        const width = (Math.max(...xs) - Math.min(...xs)).toFixed(2);
        const height = (Math.max(...ys) - Math.min(...ys)).toFixed(2);

        let perimeter = 0;
        for (let i = 0; i < pts.length; i++) {
            const next = pts[(i + 1) % pts.length];
            const dx = next.x - pts[i].x;
            const dy = next.y - pts[i].y;
            perimeter += Math.sqrt(dx * dx + dy * dy);
        }

        return {
            width,
            height,
            perimeter: perimeter.toFixed(2)
        };
    }

    async loadGeometry() {
        this.isLoading = true;
        this.handleClearMessages();
        try {
            const result = await getRaftGeometry({ recordId: this.recordId });
            this.raftTitle = result.raftName || 'Raft Foundation Geometry';
            this.raftNumber = result.raftNumber || '';
            this.packageName = result.packageName || 'Unassigned Package';
            this.isReadOnly = !result.isUpdateable;

            const loadedCorners = (result.numberOfCorners && result.numberOfCorners >= MIN_CORNERS) ?
                result.numberOfCorners : (result.coordinates && result.coordinates.length >= MIN_CORNERS ?
                    result.coordinates.length : 4);

            this.numberOfCorners = loadedCorners;
            this.savedNumberOfCorners = loadedCorners;

            const existingMap = new Map();
            if (result.coordinates && result.coordinates.length > 0) {
                result.coordinates.forEach(c => existingMap.set(c.sequence, c));
            }

            this.points = this.buildPointList(loadedCorners, existingMap);
            this.savedPoints = JSON.parse(JSON.stringify(this.points));
        } catch (error) {
            this.errorMessage = this.extractErrorMessage(error);
        } finally {
            this.isLoading = false;
        }
    }

    buildPointList(count, existingMap = new Map()) {
        const list = [];
        for (let i = 1; i <= count; i++) {
            const existing = existingMap.get(i);
            list.push({
                sequence: i,
                x: existing && existing.x !== undefined && existing.x !== null ? existing.x : null,
                y: existing && existing.y !== undefined && existing.y !== null ? existing.y : null,
                xLabel: `Point ${i} X Coordinate (m)`,
                yLabel: `Point ${i} Y Coordinate (m)`,
                badgeClass: i === 1 ? 'seq-badge first-point' : 'seq-badge'
            });
        }
        return list;
    }

    handleCornerCountChange(event) {
        const newCount = parseInt(event.detail.value, 10);
        if (isNaN(newCount) || newCount === this.numberOfCorners) {
            return;
        }

        if (newCount < this.numberOfCorners) {
            // Check if any point being trimmed has data
            const hasDataInDiscarded = this.points.slice(newCount).some(p =>
                (p.x !== null && p.x !== '') || (p.y !== null && p.y !== '')
            );

            if (hasDataInDiscarded) {
                this.pendingCornerCount = newCount;
                this.showReductionWarningModal = true;
                return;
            }
        }

        this.applyCornerCountChange(newCount);
    }

    handleConfirmCornerReduction() {
        if (this.pendingCornerCount !== null) {
            this.applyCornerCountChange(this.pendingCornerCount);
        }
        this.showReductionWarningModal = false;
        this.pendingCornerCount = null;
    }

    handleCancelCornerReduction() {
        this.showReductionWarningModal = false;
        this.pendingCornerCount = null;
    }

    applyCornerCountChange(newCount) {
        const existingMap = new Map();
        this.points.forEach(p => existingMap.set(p.sequence, p));
        this.numberOfCorners = newCount;
        this.points = this.buildPointList(newCount, existingMap);
        this.handleClearMessages();
    }

    handleCoordinateChange(event) {
        const seq = parseInt(event.target.dataset.sequence, 10);
        const axis = event.target.dataset.axis;
        const rawValue = event.target.value;
        const val = rawValue === '' ? null : Number(rawValue);

        this.points = this.points.map(p => {
            if (p.sequence === seq) {
                return {
                    ...p,
                    [axis]: val
                };
            }
            return p;
        });

        this.handleClearMessages();
    }

    handleRevert() {
        this.numberOfCorners = this.savedNumberOfCorners;
        this.points = JSON.parse(JSON.stringify(this.savedPoints));
        this.handleClearMessages();
        this.showToast('Reverted', 'Geometry changes reverted to saved state.', 'info');
    }

    async handleSave() {
        if (!this.hasValidGeometry) {
            this.errorMessage = 'Please complete all X and Y coordinates before saving.';
            return;
        }

        this.isLoading = true;
        this.isSaving = true;
        this.handleClearMessages();

        const payload = this.points.map(p => ({
            sequence: p.sequence,
            x: Number(p.x),
            y: Number(p.y)
        }));

        try {
            const result = await saveRaftGeometry({
                recordId: this.recordId,
                numberOfCorners: this.numberOfCorners,
                coordinatesJson: JSON.stringify(payload)
            });

            this.savedNumberOfCorners = result.numberOfCorners;
            const existingMap = new Map();
            if (result.coordinates) {
                result.coordinates.forEach(c => existingMap.set(c.sequence, c));
            }
            this.points = this.buildPointList(this.numberOfCorners, existingMap);
            this.savedPoints = JSON.parse(JSON.stringify(this.points));

            this.successMessage = `Successfully saved ${this.numberOfCorners}-corner raft boundary geometry.`;
            this.showToast('Success', this.successMessage, 'success');
        } catch (error) {
            this.errorMessage = this.extractErrorMessage(error);
            this.showToast('Save Failed', this.errorMessage, 'error');
        } finally {
            this.isLoading = false;
            this.isSaving = false;
        }
    }

    handleClearError() {
        this.errorMessage = '';
    }

    handleClearSuccess() {
        this.successMessage = '';
    }

    handleClearMessages() {
        this.errorMessage = '';
        this.successMessage = '';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    extractErrorMessage(error) {
        if (!error) return 'An unknown error occurred.';
        if (typeof error === 'string') return error;
        if (error.body && typeof error.body.message === 'string') {
            return error.body.message;
        }
        if (error.message) return error.message;
        return JSON.stringify(error);
    }
}
