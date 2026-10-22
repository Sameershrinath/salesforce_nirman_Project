/**
 * @description Controller for the Raft Coordinate Editor Lightning Web Component.
 *              Provides secure loading and validation of dynamic raft polygon geometries.
 */
public with sharing class RaftCoordinateController {
    public static final Integer MIN_CORNERS = 3;
    public static final Integer MAX_CORNERS = 20;

    public class CoordinatePoint implements Comparable {
        @AuraEnabled public Integer sequence { get; set; }
        @AuraEnabled public Decimal x { get; set; }
        @AuraEnabled public Decimal y { get; set; }

        public CoordinatePoint() {}

        public CoordinatePoint(Integer sequence, Decimal x, Decimal y) {
            this.sequence = sequence;
            this.x = x;
            this.y = y;
        }

        public Integer compareTo(Object compareTo) {
            CoordinatePoint other = (CoordinatePoint) compareTo;
            if (this.sequence == null && other.sequence == null) return 0;
            if (this.sequence == null) return -1;
            if (other.sequence == null) return 1;
            return this.sequence - other.sequence;
        }
    }

    public class RaftGeometryDTO {
        @AuraEnabled public Id recordId { get; set; }
        @AuraEnabled public String raftName { get; set; }
        @AuraEnabled public String raftNumber { get; set; }
        @AuraEnabled public Id packageId { get; set; }
        @AuraEnabled public String packageName { get; set; }
        @AuraEnabled public Integer numberOfCorners { get; set; }
        @AuraEnabled public List<CoordinatePoint> coordinates { get; set; }
        @AuraEnabled public Integer minCorners { get; set; }
        @AuraEnabled public Integer maxCorners { get; set; }
        @AuraEnabled public Boolean isUpdateable { get; set; }
    }

    public class ControllerException extends Exception {}

    @AuraEnabled(cacheable=true)
    public static RaftGeometryDTO getRaftGeometry(Id recordId) {
        try {
            if (recordId == null) {
                throw new ControllerException('A valid Raft record ID must be provided.');
            }

            if (!Schema.sObjectType.Raft__c.isAccessible() ||
                !Schema.sObjectType.Raft__c.fields.Name.isAccessible() ||
                !Schema.sObjectType.Raft__c.fields.Raft_Number__c.isAccessible() ||
                !Schema.sObjectType.Raft__c.fields.Construction_Package__c.isAccessible() ||
                !Schema.sObjectType.Raft__c.fields.Number_of_Corners__c.isAccessible() ||
                !Schema.sObjectType.Raft__c.fields.Coordinates_JSON__c.isAccessible()) {
                throw new ControllerException('Insufficient permissions to read Raft geometry.');
            }

            List<Raft__c> rafts = [
                SELECT Id, Name, Raft_Number__c, Construction_Package__c,
                       Construction_Package__r.Name, Number_of_Corners__c, Coordinates_JSON__c
                FROM Raft__c
                WHERE Id = :recordId
                LIMIT 1
            ];

            if (rafts.isEmpty()) {
                throw new ControllerException('Raft record not found.');
            }

            Raft__c raft = rafts[0];
            RaftGeometryDTO dto = new RaftGeometryDTO();
            dto.recordId = raft.Id;
            dto.raftName = raft.Name;
            dto.raftNumber = raft.Raft_Number__c;
            dto.packageId = raft.Construction_Package__c;
            dto.packageName = raft.Construction_Package__r != null ? raft.Construction_Package__r.Name : '';
            dto.numberOfCorners = raft.Number_of_Corners__c != null ? Integer.valueOf(raft.Number_of_Corners__c) : null;
            dto.minCorners = MIN_CORNERS;
            dto.maxCorners = MAX_CORNERS;
            dto.isUpdateable = Schema.sObjectType.Raft__c.isUpdateable() &&
                               Schema.sObjectType.Raft__c.fields.Number_of_Corners__c.isUpdateable() &&
                               Schema.sObjectType.Raft__c.fields.Coordinates_JSON__c.isUpdateable();

            dto.coordinates = new List<CoordinatePoint>();
            if (String.isNotBlank(raft.Coordinates_JSON__c)) {
                try {
                    List<CoordinatePoint> parsed = (List<CoordinatePoint>) JSON.deserialize(
                        raft.Coordinates_JSON__c, List<CoordinatePoint>.class
                    );
                    if (parsed != null) {
                        parsed.sort();
                        dto.coordinates = parsed;
                    }
                } catch (Exception ex) {
                    dto.coordinates = new List<CoordinatePoint>();
                }
            }

            return dto;
        } catch (Exception e) {
            String msg = e instanceof ControllerException ? e.getMessage() : 'Unable to load Raft geometry.';
            AuraHandledException aex = new AuraHandledException(msg);
            aex.setMessage(msg);
            throw aex;
        }
    }

    @AuraEnabled
    public static RaftGeometryDTO saveRaftGeometry(Id recordId, Integer numberOfCorners, String coordinatesJson) {
        Savepoint sp = Database.setSavepoint();
        try {
            if (recordId == null) {
                throw new ControllerException('A valid Raft record ID is required.');
            }

            if (!Schema.sObjectType.Raft__c.isUpdateable() ||
                !Schema.sObjectType.Raft__c.fields.Number_of_Corners__c.isUpdateable() ||
                !Schema.sObjectType.Raft__c.fields.Coordinates_JSON__c.isUpdateable()) {
                throw new ControllerException('Insufficient permissions to update Raft geometry.');
            }

            if (numberOfCorners == null) {
                throw new ControllerException('Number of corners is required.');
            }
            if (numberOfCorners < MIN_CORNERS || numberOfCorners > MAX_CORNERS) {
                throw new ControllerException('Number of corners must be between ' + MIN_CORNERS + ' and ' + MAX_CORNERS + '.');
            }

            if (String.isBlank(coordinatesJson)) {
                throw new ControllerException('Coordinate JSON payload cannot be empty.');
            }

            List<CoordinatePoint> points;
            try {
                points = (List<CoordinatePoint>) JSON.deserialize(coordinatesJson, List<CoordinatePoint>.class);
            } catch (Exception jsonEx) {
                throw new ControllerException('Malformed coordinate JSON format: ' + jsonEx.getMessage());
            }

            if (points == null || points.isEmpty()) {
                throw new ControllerException('Coordinates array cannot be empty.');
            }

            if (points.size() != numberOfCorners) {
                throw new ControllerException('The number of coordinate points (' + points.size() +
                    ') must exactly match the number of corners (' + numberOfCorners + ').');
            }

            Set<Integer> seenSequences = new Set<Integer>();
            for (Integer i = 0; i < points.size(); i++) {
                CoordinatePoint pt = points[i];
                if (pt == null) {
                    throw new ControllerException('Coordinate point at index ' + i + ' is null.');
                }
                if (pt.sequence == null) {
                    throw new ControllerException('Every coordinate point must have a sequence number.');
                }
                if (seenSequences.contains(pt.sequence)) {
                    throw new ControllerException('Duplicate sequence number found: ' + pt.sequence + '. Each sequence must be unique.');
                }
                seenSequences.add(pt.sequence);

                if (pt.x == null) {
                    throw new ControllerException('Point ' + pt.sequence + ' is missing an X coordinate.');
                }
                if (pt.y == null) {
                    throw new ControllerException('Point ' + pt.sequence + ' is missing a Y coordinate.');
                }

                Double xVal = Double.valueOf(pt.x);
                Double yVal = Double.valueOf(pt.y);
                if (Double.isNaN(xVal) || Double.isInfinite(xVal)) {
                    throw new ControllerException('Point ' + pt.sequence + ' has an invalid X coordinate value.');
                }
                if (Double.isNaN(yVal) || Double.isInfinite(yVal)) {
                    throw new ControllerException('Point ' + pt.sequence + ' has an invalid Y coordinate value.');
                }
            }

            for (Integer seq = 1; seq <= numberOfCorners; seq++) {
                if (!seenSequences.contains(seq)) {
                    throw new ControllerException('Sequence numbers must be consecutive integers starting at 1. Missing sequence: ' + seq + '.');
                }
            }

            points.sort();
            String canonicalJson = JSON.serialize(points);

            List<Raft__c> rafts = [
                SELECT Id, Number_of_Corners__c, Coordinates_JSON__c
                FROM Raft__c
                WHERE Id = :recordId
                FOR UPDATE
            ];
            if (rafts.isEmpty()) {
                throw new ControllerException('Raft record not found for Id: ' + recordId);
            }

            Raft__c raftToUpdate = new Raft__c(
                Id = recordId,
                Number_of_Corners__c = numberOfCorners,
                Coordinates_JSON__c = canonicalJson
            );
            update raftToUpdate;

            return getRaftGeometry(recordId);
        } catch (Exception e) {
            Database.rollback(sp);
            String userMsg = (e instanceof ControllerException || e instanceof DmlException) ?
                e.getMessage() : 'An unexpected error occurred while saving raft geometry.';
            AuraHandledException aex = new AuraHandledException(userMsg);
            aex.setMessage(userMsg);
            throw aex;
        }
    }
}
