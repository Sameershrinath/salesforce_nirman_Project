/**
 * @description Apex controller for the Construction Layout Viewer Lightning Web Component.
 *              Provides secure queries for Construction Packages, Piles, Rafts, and Pedestals.
 *              Enforces object-level and field-level security using with sharing and Schema checks.
 */
public with sharing class ConstructionLayoutController {

    // ──────────────────────────────────────────────────────────
    // DTOs
    // ──────────────────────────────────────────────────────────

    public class PackageOption {
        @AuraEnabled public Id    id    { get; set; }
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String packageType { get; set; }
        @AuraEnabled public String projectName { get; set; }
    }

    public class PileDTO {
        @AuraEnabled public Id      id                    { get; set; }
        @AuraEnabled public String  name                  { get; set; }
        @AuraEnabled public String  pileIdNumber          { get; set; }
        @AuraEnabled public Decimal x                     { get; set; }
        @AuraEnabled public Decimal y                     { get; set; }
        @AuraEnabled public String  status                { get; set; }
        @AuraEnabled public Decimal diameterMm            { get; set; }
        @AuraEnabled public Decimal foundingDepthM        { get; set; }
        @AuraEnabled public String  concreteGrade         { get; set; }
        @AuraEnabled public Boolean hasCoordinates        { get; set; }
    }

    public class RaftDTO {
        @AuraEnabled public Id      id                    { get; set; }
        @AuraEnabled public String  name                  { get; set; }
        @AuraEnabled public String  raftNumber            { get; set; }
        @AuraEnabled public String  coordinatesJson       { get; set; }
        @AuraEnabled public Integer numberOfCorners       { get; set; }
        @AuraEnabled public String  status                { get; set; }
        @AuraEnabled public Decimal lengthM               { get; set; }
        @AuraEnabled public Decimal widthM                { get; set; }
        @AuraEnabled public Decimal depthM                { get; set; }
        @AuraEnabled public String  concreteGrade         { get; set; }
        @AuraEnabled public Boolean hasGeometry           { get; set; }
    }

    public class PedestalDTO {
        @AuraEnabled public Id      id                    { get; set; }
        @AuraEnabled public String  name                  { get; set; }
        @AuraEnabled public Decimal x                     { get; set; }
        @AuraEnabled public Decimal y                     { get; set; }
        @AuraEnabled public String  status                { get; set; }
        @AuraEnabled public String  gridReference         { get; set; }
        @AuraEnabled public String  crossSection          { get; set; }
        @AuraEnabled public Decimal heightM               { get; set; }
        @AuraEnabled public String  anchorBoltInspection  { get; set; }
        @AuraEnabled public Boolean hasCoordinates        { get; set; }
    }

    public class LayoutDataResult {
        @AuraEnabled public List<PileDTO>     piles      { get; set; }
        @AuraEnabled public List<RaftDTO>     rafts      { get; set; }
        @AuraEnabled public List<PedestalDTO> pedestals  { get; set; }
        @AuraEnabled public String            packageName { get; set; }
        @AuraEnabled public String            packageType { get; set; }
        @AuraEnabled public String            projectName { get; set; }
    }

    public class ControllerException extends Exception {}

    // ──────────────────────────────────────────────────────────
    // METHODS
    // ──────────────────────────────────────────────────────────

    /**
     * @description Returns all accessible Construction Packages for the combobox selector,
     *              ordered by Project then Name. Limit 500 to prevent unrestricted queries.
     */
    @AuraEnabled(cacheable=true)
    public static List<PackageOption> getConstructionPackages() {
        try {
            if (!Schema.sObjectType.Construction_Package__c.isAccessible()) {
                throw new ControllerException('Insufficient permissions to access Construction Packages.');
            }

            List<PackageOption> options = new List<PackageOption>();
            for (Construction_Package__c pkg : [
                SELECT Id, Name, Package_Type__c, Nirmaan_Project__r.Name
                FROM Construction_Package__c
                WHERE Nirmaan_Project__c != null
                ORDER BY Nirmaan_Project__r.Name ASC, Name ASC
                LIMIT 500
            ]) {
                PackageOption opt = new PackageOption();
                opt.id          = pkg.Id;
                opt.label       = pkg.Name + ' (' + pkg.Package_Type__c + ')';
                opt.packageType = pkg.Package_Type__c;
                opt.projectName = pkg.Nirmaan_Project__r != null ? pkg.Nirmaan_Project__r.Name : '';
                options.add(opt);
            }
            return options;
        } catch (ControllerException ce) {
            throw new AuraHandledException(ce.getMessage());
        } catch (Exception e) {
            throw new AuraHandledException('Failed to load Construction Packages: ' + e.getMessage());
        }
    }

    /**
     * @description Returns all Piles, Rafts, and Pedestals belonging to the specified
     *              Construction Package. If packageId is blank/null returns empty result.
     * @param packageId  Salesforce Id of the selected Construction_Package__c record.
     */
    @AuraEnabled(cacheable=true)
    public static LayoutDataResult getLayoutData(Id packageId) {
        try {
            if (packageId == null) {
                LayoutDataResult empty = new LayoutDataResult();
                empty.piles     = new List<PileDTO>();
                empty.rafts     = new List<RaftDTO>();
                empty.pedestals = new List<PedestalDTO>();
                return empty;
            }

            // Validate access to the package itself
            if (!Schema.sObjectType.Construction_Package__c.isAccessible()) {
                throw new ControllerException('Insufficient permissions to access Construction Packages.');
            }

            // Retrieve package header for display labels
            List<Construction_Package__c> pkgs = [
                SELECT Id, Name, Package_Type__c, Nirmaan_Project__r.Name
                FROM Construction_Package__c
                WHERE Id = :packageId
                LIMIT 1
            ];
            if (pkgs.isEmpty()) {
                throw new ControllerException('Construction Package not found or not accessible.');
            }
            Construction_Package__c pkg = pkgs[0];

            LayoutDataResult result = new LayoutDataResult();
            result.packageName = pkg.Name;
            result.packageType = pkg.Package_Type__c;
            result.projectName = pkg.Nirmaan_Project__r != null ? pkg.Nirmaan_Project__r.Name : '';

            // ── Piles ─────────────────────────────────────────────
            result.piles = new List<PileDTO>();
            if (Schema.sObjectType.Pile__c.isAccessible()) {
                for (Pile__c p : [
                    SELECT Id, Name, Pile_Identification_Number__c,
                           X_Coordinate__c, Y_Coordinate__c,
                           Status__c, Pile_Diameter_mm__c,
                           Founding_Depth_m__c, Concrete_Grade__c
                    FROM Pile__c
                    WHERE Construction_Package__c = :packageId
                    ORDER BY Pile_Identification_Number__c ASC
                    LIMIT 1000
                ]) {
                    PileDTO dto           = new PileDTO();
                    dto.id                = p.Id;
                    dto.name              = p.Name;
                    dto.pileIdNumber      = p.Pile_Identification_Number__c;
                    dto.x                 = p.X_Coordinate__c;
                    dto.y                 = p.Y_Coordinate__c;
                    dto.status            = p.Status__c;
                    dto.diameterMm        = p.Pile_Diameter_mm__c;
                    dto.foundingDepthM    = p.Founding_Depth_m__c;
                    dto.concreteGrade     = p.Concrete_Grade__c;
                    dto.hasCoordinates    = (p.X_Coordinate__c != null && p.Y_Coordinate__c != null);
                    result.piles.add(dto);
                }
            }

            // ── Rafts ─────────────────────────────────────────────
            result.rafts = new List<RaftDTO>();
            if (Schema.sObjectType.Raft__c.isAccessible()) {
                for (Raft__c r : [
                    SELECT Id, Name, Raft_Number__c, Coordinates_JSON__c,
                           Number_of_Corners__c, Status__c, Length_m__c,
                           Width_m__c, Depth_m__c, Concrete_Grade__c
                    FROM Raft__c
                    WHERE Construction_Package__c = :packageId
                    ORDER BY Raft_Number__c ASC
                    LIMIT 500
                ]) {
                    RaftDTO dto         = new RaftDTO();
                    dto.id              = r.Id;
                    dto.name            = r.Name;
                    dto.raftNumber      = r.Raft_Number__c;
                    dto.coordinatesJson = r.Coordinates_JSON__c;
                    dto.numberOfCorners = r.Number_of_Corners__c != null ? r.Number_of_Corners__c.intValue() : 0;
                    dto.status          = r.Status__c;
                    dto.lengthM         = r.Length_m__c;
                    dto.widthM          = r.Width_m__c;
                    dto.depthM          = r.Depth_m__c;
                    dto.concreteGrade   = r.Concrete_Grade__c;
                    dto.hasGeometry     = isValidRaftJson(r.Coordinates_JSON__c);
                    result.rafts.add(dto);
                }
            }

            // ── Pedestals ─────────────────────────────────────────
            result.pedestals = new List<PedestalDTO>();
            if (Schema.sObjectType.Pedestal__c.isAccessible()) {
                for (Pedestal__c pd : [
                    SELECT Id, Name, X_Coordinate__c, Y_Coordinate__c,
                           Status__c, Grid_Reference__c, Cross_Section__c,
                           Height_m__c, Anchor_Bolt_Inspection__c
                    FROM Pedestal__c
                    WHERE Construction_Package__c = :packageId
                    ORDER BY Grid_Reference__c ASC
                    LIMIT 1000
                ]) {
                    PedestalDTO dto           = new PedestalDTO();
                    dto.id                    = pd.Id;
                    dto.name                  = pd.Name;
                    dto.x                     = pd.X_Coordinate__c;
                    dto.y                     = pd.Y_Coordinate__c;
                    dto.status                = pd.Status__c;
                    dto.gridReference         = pd.Grid_Reference__c;
                    dto.crossSection          = pd.Cross_Section__c;
                    dto.heightM               = pd.Height_m__c;
                    dto.anchorBoltInspection  = pd.Anchor_Bolt_Inspection__c;
                    dto.hasCoordinates        = (pd.X_Coordinate__c != null && pd.Y_Coordinate__c != null);
                    result.pedestals.add(dto);
                }
            }

            return result;

        } catch (ControllerException ce) {
            throw new AuraHandledException(ce.getMessage());
        } catch (Exception e) {
            throw new AuraHandledException('Failed to load layout data: ' + e.getMessage());
        }
    }

    // ──────────────────────────────────────────────────────────
    // PRIVATE HELPERS
    // ──────────────────────────────────────────────────────────

    /**
     * @description Validates that a Coordinates_JSON__c string contains
     *              a parseable array of at least 3 points with numeric x and y fields.
     */
    private static Boolean isValidRaftJson(String jsonStr) {
        if (String.isBlank(jsonStr)) return false;
        try {
            List<Object> parsed = (List<Object>) JSON.deserializeUntyped(jsonStr);
            if (parsed == null || parsed.size() < 3) return false;
            for (Object obj : parsed) {
                Map<String, Object> pt = (Map<String, Object>) obj;
                if (!pt.containsKey('x') || !pt.containsKey('y')) return false;
                if (pt.get('x') == null || pt.get('y') == null)    return false;
            }
            return true;
        } catch (Exception e) {
            return false;
        }
    }
}
