/**
 * @description Unit tests for ConstructionLayoutController.
 *              Covers package loading, layout data retrieval, null safety, and JSON validation.
 */
@IsTest
private class ConstructionLayoutControllerTest {

    @TestSetup
    static void setupTestData() {
        Nirmaan_Project__c proj = new Nirmaan_Project__c(
            Name             = 'Test Layout Project',
            Project_Code__c  = 'TEST-LAY-01',
            Status__c        = 'In Progress'
        );
        insert proj;

        Construction_Package__c pkg = new Construction_Package__c(
            Name                = 'Test Boiler Package',
            Nirmaan_Project__c  = proj.Id,
            Package_Type__c     = 'Boiler Area',
            Status__c           = 'Substructure / Foundations'
        );
        insert pkg;

        Construction_Package__c pkg2 = new Construction_Package__c(
            Name                = 'Test Chimney Package',
            Nirmaan_Project__c  = proj.Id,
            Package_Type__c     = 'Chimney (Stack)',
            Status__c           = 'Substructure / Foundations'
        );
        insert pkg2;

        // Piles with and without coordinates
        List<Pile__c> piles = new List<Pile__c>();
        piles.add(new Pile__c(
            Name                        = 'Test Pile P-01',
            Construction_Package__c     = pkg.Id,
            Pile_Identification_Number__c = 'TEST-P-001',
            Pile_Diameter_mm__c         = 1000,
            Cut_Off_Level_m__c          = 48.500,
            Founding_Depth_m__c         = 28.50,
            Concrete_Grade__c           = 'M35',
            Status__c                   = 'Completed',
            X_Coordinate__c             = 1100.000,
            Y_Coordinate__c             = 2000.000
        ));
        piles.add(new Pile__c(
            Name                        = 'Test Pile P-02',
            Construction_Package__c     = pkg.Id,
            Pile_Identification_Number__c = 'TEST-P-002',
            Pile_Diameter_mm__c         = 1000,
            Cut_Off_Level_m__c          = 48.500,
            Founding_Depth_m__c         = 28.50,
            Concrete_Grade__c           = 'M35',
            Status__c                   = 'Drilling / Boring In-Progress'
            // No coordinates intentionally
        ));
        insert piles;

        // Rafts with valid, invalid, and null JSON
        Raft__c raftValid = new Raft__c(
            Name                    = 'Test Raft R-01',
            Raft_Number__c          = 'TEST-RFT-001',
            Construction_Package__c = pkg.Id,
            Length_m__c             = 20.0,
            Width_m__c              = 15.0,
            Depth_m__c              = 3.0,
            Concrete_Grade__c       = 'M35',
            Status__c               = 'Cast and Cured',
            Number_of_Corners__c    = 4,
            Coordinates_JSON__c     = '[{"sequence":1,"x":1080.0,"y":1980.0},{"sequence":2,"x":1100.0,"y":1980.0},{"sequence":3,"x":1100.0,"y":1995.0},{"sequence":4,"x":1080.0,"y":1995.0}]'
        );

        Raft__c raftNoJson = new Raft__c(
            Name                    = 'Test Raft R-02',
            Raft_Number__c          = 'TEST-RFT-002',
            Construction_Package__c = pkg.Id,
            Length_m__c             = 15.0,
            Width_m__c              = 10.0,
            Depth_m__c              = 2.5,
            Concrete_Grade__c       = 'M35',
            Status__c               = 'Excavation and Dressing'
        );

        Raft__c raftBadJson = new Raft__c(
            Name                    = 'Test Raft R-03',
            Raft_Number__c          = 'TEST-RFT-003',
            Construction_Package__c = pkg.Id,
            Length_m__c             = 10.0,
            Width_m__c              = 8.0,
            Depth_m__c              = 2.0,
            Concrete_Grade__c       = 'M30',
            Status__c               = 'PCC / Mud Mat Laid',
            Coordinates_JSON__c     = 'not-valid-json'
        );
        insert new List<Raft__c>{ raftValid, raftNoJson, raftBadJson };

        // Pedestals
        Pedestal__c ped = new Pedestal__c(
            Name                    = 'Test Pedestal PED-01',
            Construction_Package__c = pkg.Id,
            Status__c               = 'Concreted',
            Grid_Reference__c       = 'Grid A-1',
            Cross_Section__c        = '2000mm x 2000mm',
            Height_m__c             = 4.5,
            X_Coordinate__c         = 1085.0,
            Y_Coordinate__c         = 1985.0
        );
        insert ped;
    }

    @IsTest
    static void testGetConstructionPackages() {
        Test.startTest();
        List<ConstructionLayoutController.PackageOption> opts =
            ConstructionLayoutController.getConstructionPackages();
        Test.stopTest();

        System.assertNotEquals(null, opts, 'Package list should not be null');
        System.assert(opts.size() >= 2, 'Should return at least 2 test packages');

        Boolean foundBoiler = false;
        for (ConstructionLayoutController.PackageOption o : opts) {
            System.assertNotEquals(null, o.id, 'Option Id should not be null');
            System.assertNotEquals(null, o.label, 'Option label should not be null');
            if (o.label.contains('Test Boiler Package')) foundBoiler = true;
        }
        System.assert(foundBoiler, 'Boiler test package should appear in options');
    }

    @IsTest
    static void testGetLayoutDataNullId() {
        Test.startTest();
        ConstructionLayoutController.LayoutDataResult result =
            ConstructionLayoutController.getLayoutData(null);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null for null packageId');
        System.assertEquals(0, result.piles.size(),     'Piles should be empty for null id');
        System.assertEquals(0, result.rafts.size(),     'Rafts should be empty for null id');
        System.assertEquals(0, result.pedestals.size(), 'Pedestals should be empty for null id');
    }

    @IsTest
    static void testGetLayoutDataValidPackage() {
        Construction_Package__c pkg = [SELECT Id FROM Construction_Package__c WHERE Name = 'Test Boiler Package' LIMIT 1];

        Test.startTest();
        ConstructionLayoutController.LayoutDataResult result =
            ConstructionLayoutController.getLayoutData(pkg.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals('Test Boiler Package', result.packageName, 'Package name should match');
        System.assertEquals('Boiler Area', result.packageType, 'Package type should match');

        // Piles
        System.assertEquals(2, result.piles.size(), 'Should return 2 piles for boiler package');
        Integer pilesWithCoords = 0;
        for (ConstructionLayoutController.PileDTO p : result.piles) {
            if (p.hasCoordinates) pilesWithCoords++;
        }
        System.assertEquals(1, pilesWithCoords, 'Exactly 1 pile should have coordinates');

        // Rafts
        System.assertEquals(3, result.rafts.size(), 'Should return 3 rafts for boiler package');
        Integer raftsWithGeom = 0;
        for (ConstructionLayoutController.RaftDTO r : result.rafts) {
            if (r.hasGeometry) raftsWithGeom++;
        }
        System.assertEquals(1, raftsWithGeom, 'Exactly 1 raft should have valid geometry (4-point JSON)');

        // Pedestals
        System.assertEquals(1, result.pedestals.size(), 'Should return 1 pedestal for boiler package');
        System.assert(result.pedestals[0].hasCoordinates, 'Pedestal should have coordinates');
    }

    @IsTest
    static void testGetLayoutDataEmptyPackage() {
        Construction_Package__c pkg = [SELECT Id FROM Construction_Package__c WHERE Name = 'Test Chimney Package' LIMIT 1];

        Test.startTest();
        ConstructionLayoutController.LayoutDataResult result =
            ConstructionLayoutController.getLayoutData(pkg.Id);
        Test.stopTest();

        System.assertEquals(0, result.piles.size(),     'Chimney package should have no piles');
        System.assertEquals(0, result.rafts.size(),     'Chimney package should have no rafts');
        System.assertEquals(0, result.pedestals.size(), 'Chimney package should have no pedestals');
    }

    @IsTest
    static void testGetLayoutDataInvalidId() {
        Boolean exceptionThrown = false;
        String prefix = Construction_Package__c.sObjectType.getDescribe().getKeyPrefix();
        Id fakeId = (Id) (prefix + '000000000001AAA');

        Test.startTest();
        try {
            ConstructionLayoutController.getLayoutData(fakeId);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        System.assert(exceptionThrown, 'Should throw AuraHandledException for non-existent package ID');
    }

    @IsTest
    static void testRaftJsonValidation() {
        Construction_Package__c pkg = [SELECT Id FROM Construction_Package__c WHERE Name = 'Test Boiler Package' LIMIT 1];

        Test.startTest();
        ConstructionLayoutController.LayoutDataResult result =
            ConstructionLayoutController.getLayoutData(pkg.Id);
        Test.stopTest();

        Map<String, Boolean> raftGeomMap = new Map<String, Boolean>();
        for (ConstructionLayoutController.RaftDTO r : result.rafts) {
            raftGeomMap.put(r.raftNumber, r.hasGeometry);
        }

        System.assertEquals(true,  raftGeomMap.get('TEST-RFT-001'), 'Valid JSON raft should have geometry');
        System.assertEquals(false, raftGeomMap.get('TEST-RFT-002'), 'Null JSON raft should NOT have geometry');
        System.assertEquals(false, raftGeomMap.get('TEST-RFT-003'), 'Malformed JSON raft should NOT have geometry');
    }
}
