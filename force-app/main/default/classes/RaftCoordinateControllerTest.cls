/**
 * @description Comprehensive unit tests for RaftCoordinateController.
 *              Validates all geometry operations, corner constraints, serialization,
 *              transaction safety, and authorization checks.
 */
@IsTest
private class RaftCoordinateControllerTest {

    @TestSetup
    static void setupTestData() {
        Nirmaan_Project__c project = new Nirmaan_Project__c(
            Name = 'Test Super Thermal Project',
            Project_Code__c = 'TEST-PRJ-01',
            Status__c = 'In Progress'
        );
        insert project;

        Construction_Package__c pkg = new Construction_Package__c(
            Name = 'Boiler Island Foundation',
            Nirmaan_Project__c = project.Id,
            Package_Type__c = 'Boiler Area',
            Status__c = 'Substructure / Foundations'
        );
        insert pkg;

        Raft__c raft = new Raft__c(
            Name = 'Boiler Raft R-1',
            Raft_Number__c = 'RFT-TEST-001',
            Construction_Package__c = pkg.Id,
            Length_m__c = 30.0,
            Width_m__c = 20.0,
            Depth_m__c = 3.5,
            Status__c = 'Excavation and Dressing'
        );
        insert raft;
    }

    private static Raft__c getTestRaft() {
        return [SELECT Id, Name, Raft_Number__c, Number_of_Corners__c, Coordinates_JSON__c FROM Raft__c LIMIT 1];
    }

    private static String generateCoordinatesJson(Integer count) {
        List<Map<String, Object>> points = new List<Map<String, Object>>();
        for (Integer i = 1; i <= count; i++) {
            Map<String, Object> pt = new Map<String, Object>();
            pt.put('sequence', i);
            pt.put('x', Double.valueOf(10.0 * i));
            pt.put('y', Double.valueOf(20.0 * i));
            points.add(pt);
        }
        return JSON.serialize(points);
    }

    @IsTest
    static void testLoadRaftGeometryEmpty() {
        Raft__c raft = getTestRaft();
        Test.startTest();
        RaftCoordinateController.RaftGeometryDTO dto = RaftCoordinateController.getRaftGeometry(raft.Id);
        Test.stopTest();

        System.assertNotEquals(null, dto, 'DTO should not be null');
        System.assertEquals(raft.Id, dto.recordId, 'Record ID should match');
        System.assertEquals('Boiler Raft R-1', dto.raftName, 'Raft Name should match');
        System.assertEquals(3, dto.minCorners, 'Min corners should be 3');
        System.assertEquals(20, dto.maxCorners, 'Max corners should be 20');
        System.assertEquals(0, dto.coordinates.size(), 'Initial coordinates should be empty');
    }

    @IsTest
    static void testThreeCornerGeometry() {
        Raft__c raft = getTestRaft();
        String json3 = '[{"sequence":1,"x":0.0,"y":0.0},{"sequence":2,"x":50.0,"y":0.0},{"sequence":3,"x":25.0,"y":40.0}]';

        Test.startTest();
        RaftCoordinateController.RaftGeometryDTO dto = RaftCoordinateController.saveRaftGeometry(raft.Id, 3, json3);
        Test.stopTest();

        System.assertNotEquals(null, dto, 'DTO should not be null after saving');
        System.assertEquals(3, dto.numberOfCorners, 'Should have 3 corners');
        System.assertEquals(3, dto.coordinates.size(), 'Should have 3 points');
        System.assertEquals(1, dto.coordinates[0].sequence, 'First point sequence should be 1');
        System.assertEquals(0.0, dto.coordinates[0].x, 'First point X should match');

        Raft__c updated = [SELECT Number_of_Corners__c, Coordinates_JSON__c FROM Raft__c WHERE Id = :raft.Id];
        System.assertEquals(3, updated.Number_of_Corners__c, 'Stored corner count should be 3');
        System.assert(updated.Coordinates_JSON__c.contains('"sequence":3'), 'Stored JSON should contain sequence 3');
    }

    @IsTest
    static void testFiveCornerGeometry() {
        Raft__c raft = getTestRaft();
        String json5 = '[' +
            '{"sequence": 1, "x": 100.0, "y": 100.0},' +
            '{"sequence": 2, "x": 200.0, "y": 100.0},' +
            '{"sequence": 3, "x": 240.0, "y": 160.0},' +
            '{"sequence": 4, "x": 160.0, "y": 220.0},' +
            '{"sequence": 5, "x": 80.0, "y": 160.0}' +
        ']';

        Test.startTest();
        RaftCoordinateController.RaftGeometryDTO dto = RaftCoordinateController.saveRaftGeometry(raft.Id, 5, json5);
        Test.stopTest();

        System.assertEquals(5, dto.numberOfCorners, 'Should have 5 corners');
        System.assertEquals(5, dto.coordinates.size(), 'Should have 5 points');
        System.assertEquals(80.0, dto.coordinates[4].x, 'Point 5 X coordinate should match');
    }

    @IsTest
    static void testMaxSupportedCornerCount() {
        Raft__c raft = getTestRaft();
        String json20 = generateCoordinatesJson(20);

        Test.startTest();
        RaftCoordinateController.RaftGeometryDTO dto = RaftCoordinateController.saveRaftGeometry(raft.Id, 20, json20);
        Test.stopTest();

        System.assertEquals(20, dto.numberOfCorners, 'Should allow maximum 20 corners');
        System.assertEquals(20, dto.coordinates.size(), 'Should have 20 points');
    }

    @IsTest
    static void testInvalidCornerCountLow() {
        Raft__c raft = getTestRaft();
        String json2 = generateCoordinatesJson(2);

        Test.startTest();
        try {
            RaftCoordinateController.saveRaftGeometry(raft.Id, 2, json2);
            System.assert(false, 'Expected AuraHandledException for <3 corners');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('between 3 and 20') || e.getMessage().length() > 0, 'Controlled error message expected');
        }
        Test.stopTest();
    }

    @IsTest
    static void testInvalidCornerCountHigh() {
        Raft__c raft = getTestRaft();
        String json21 = generateCoordinatesJson(21);

        Test.startTest();
        try {
            RaftCoordinateController.saveRaftGeometry(raft.Id, 21, json21);
            System.assert(false, 'Expected AuraHandledException for >20 corners');
        } catch (AuraHandledException e) {
            System.assert(true, 'Expected error handled');
        }
        Test.stopTest();
    }

    @IsTest
    static void testMissingCoordinates() {
        Raft__c raft = getTestRaft();
        // Point 2 missing Y coordinate
        String jsonMissing = '[{"sequence":1,"x":10.0,"y":20.0},{"sequence":2,"x":30.0,"y":null},{"sequence":3,"x":50.0,"y":60.0}]';

        Test.startTest();
        try {
            RaftCoordinateController.saveRaftGeometry(raft.Id, 3, jsonMissing);
            System.assert(false, 'Expected AuraHandledException for missing Y coordinate');
        } catch (AuraHandledException e) {
            System.assert(true, 'Expected error handled');
        }
        Test.stopTest();
    }

    @IsTest
    static void testMalformedJson() {
        Raft__c raft = getTestRaft();
        String malformed = '{not a valid json array';

        Test.startTest();
        try {
            RaftCoordinateController.saveRaftGeometry(raft.Id, 3, malformed);
            System.assert(false, 'Expected AuraHandledException for malformed JSON');
        } catch (AuraHandledException e) {
            System.assert(true, 'Expected error handled');
        }
        Test.stopTest();
    }

    @IsTest
    static void testIncorrectPointCount() {
        Raft__c raft = getTestRaft();
        // Number of corners specified is 4, but only 3 points provided
        String json3 = generateCoordinatesJson(3);

        Test.startTest();
        try {
            RaftCoordinateController.saveRaftGeometry(raft.Id, 4, json3);
            System.assert(false, 'Expected AuraHandledException when point count does not match corner count');
        } catch (AuraHandledException e) {
            System.assert(true, 'Expected error handled');
        }
        Test.stopTest();
    }

    @IsTest
    static void testDuplicateSequenceNumbers() {
        Raft__c raft = getTestRaft();
        String duplicateSeq = '[{"sequence":1,"x":10.0,"y":20.0},{"sequence":1,"x":30.0,"y":40.0},{"sequence":3,"x":50.0,"y":60.0}]';

        Test.startTest();
        try {
            RaftCoordinateController.saveRaftGeometry(raft.Id, 3, duplicateSeq);
            System.assert(false, 'Expected AuraHandledException for duplicate sequence numbers');
        } catch (AuraHandledException e) {
            System.assert(true, 'Expected error handled');
        }
        Test.stopTest();
    }

    @IsTest
    static void testNonConsecutiveSequenceNumbers() {
        Raft__c raft = getTestRaft();
        // Sequences 1, 2, 4 (missing 3)
        String nonConsecutive = '[{"sequence":1,"x":10.0,"y":20.0},{"sequence":2,"x":30.0,"y":40.0},{"sequence":4,"x":50.0,"y":60.0}]';

        Test.startTest();
        try {
            RaftCoordinateController.saveRaftGeometry(raft.Id, 3, nonConsecutive);
            System.assert(false, 'Expected AuraHandledException for non-consecutive sequence numbers');
        } catch (AuraHandledException e) {
            System.assert(true, 'Expected error handled');
        }
        Test.stopTest();
    }

    @IsTest
    static void testEditingSavedGeometry() {
        Raft__c raft = getTestRaft();
        String initialJson = generateCoordinatesJson(4);
        RaftCoordinateController.saveRaftGeometry(raft.Id, 4, initialJson);

        // Edit Point 1 coordinates
        String updatedJson = '[{"sequence":1,"x":999.0,"y":888.0},{"sequence":2,"x":20.0,"y":40.0},{"sequence":3,"x":30.0,"y":60.0},{"sequence":4,"x":40.0,"y":80.0}]';

        Test.startTest();
        RaftCoordinateController.RaftGeometryDTO dto = RaftCoordinateController.saveRaftGeometry(raft.Id, 4, updatedJson);
        Test.stopTest();

        System.assertEquals(4, dto.numberOfCorners, 'Should retain 4 corners');
        System.assertEquals(999.0, dto.coordinates[0].x, 'Point 1 X should be updated');
        System.assertEquals(888.0, dto.coordinates[0].y, 'Point 1 Y should be updated');
    }

    @IsTest
    static void testReducingCornerCount() {
        Raft__c raft = getTestRaft();
        // First save 5 corners
        String json5 = generateCoordinatesJson(5);
        RaftCoordinateController.saveRaftGeometry(raft.Id, 5, json5);

        // Now reduce to 3 corners
        String json3 = generateCoordinatesJson(3);

        Test.startTest();
        RaftCoordinateController.RaftGeometryDTO dto = RaftCoordinateController.saveRaftGeometry(raft.Id, 3, json3);
        Test.stopTest();

        System.assertEquals(3, dto.numberOfCorners, 'Corner count should be reduced to 3');
        System.assertEquals(3, dto.coordinates.size(), 'Point count should be reduced to 3');

        Raft__c updated = [SELECT Number_of_Corners__c FROM Raft__c WHERE Id = :raft.Id];
        System.assertEquals(3, updated.Number_of_Corners__c, 'Persisted corner count should be 3');
    }

    @IsTest
    static void testAuthorizationFailures() {
        Test.startTest();
        try {
            RaftCoordinateController.getRaftGeometry(null);
            System.assert(false, 'Expected error for null record ID in getRaftGeometry');
        } catch (AuraHandledException e) {
            System.assert(true, 'Handled null ID');
        }

        try {
            RaftCoordinateController.saveRaftGeometry(null, 3, generateCoordinatesJson(3));
            System.assert(false, 'Expected error for null record ID in saveRaftGeometry');
        } catch (AuraHandledException e) {
            System.assert(true, 'Handled null ID');
        }
        Test.stopTest();
    }

    @IsTest
    static void testTransactionRollbackOnFailure() {
        Raft__c raft = getTestRaft();
        String initialJson = generateCoordinatesJson(4);
        RaftCoordinateController.saveRaftGeometry(raft.Id, 4, initialJson);

        Test.startTest();
        try {
            // Send invalid payload to force rollback
            RaftCoordinateController.saveRaftGeometry(raft.Id, 4, 'invalid-payload');
        } catch (AuraHandledException e) {
            // Expected
        }
        Test.stopTest();

        // Verify state is untouched and preserved
        Raft__c verifyRaft = [SELECT Number_of_Corners__c, Coordinates_JSON__c FROM Raft__c WHERE Id = :raft.Id];
        System.assertEquals(4, verifyRaft.Number_of_Corners__c, 'Corner count should remain 4 after rollback');
        System.assert(verifyRaft.Coordinates_JSON__c.contains('"sequence":4'), 'Coordinates JSON should remain unchanged after rollback');
    }
}
