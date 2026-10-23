// =========================================================================
// NIRMAAN 2.0 - Realistic Engineering Coordinates Generator
// Generates survey-accurate industrial plant coordinates:
// - Chimney piles in circular PCD layout (concentric annular ring)
// - Chimney raft as 16-corner annular polygon
// - FGD Absorber raft as 8-corner octagonal scrubber pad
// - TG Machine mat as 8-corner stepped deck with condenser pit
// - Boiler rafts as stepped 6/8-corner polygons with orthogonal pile grid
// - Switchyard gantry pedestals in linear transmission bay alignment
// =========================================================================

// -------------------------------------------------------------------------
// 1. UPDATE PILES
// -------------------------------------------------------------------------
List<Pile__c> pilesToUpdate = new List<Pile__c>();

// Chimney Center: (1600.0, 2200.0)
// Chimney Annular Pile Group: Circular PCD (Pitch Circle Diameter) = 34.0m -> Radius = 17.0m
// Piles distributed evenly at 72-degree intervals (circular pattern)
Double chimneyCenterX = 1600.0;
Double chimneyCenterY = 2200.0;
Double chimneyPcdRadius = 17.0;

List<Pile__c> chimneyPiles = [
    SELECT Id, Name, Pile_Identification_Number__c 
    FROM Pile__c 
    WHERE Construction_Package__r.Package_Type__c = 'Chimney (Stack)'
    ORDER BY Pile_Identification_Number__c ASC
];

for (Integer i = 0; i < chimneyPiles.size(); i++) {
    Double angleRad = (i * 2.0 * Math.PI) / Double.valueOf(chimneyPiles.size());
    Double calcX = chimneyCenterX + chimneyPcdRadius * Math.cos(angleRad);
    Double calcY = chimneyCenterY + chimneyPcdRadius * Math.sin(angleRad);
    
    Pile__c p = chimneyPiles[i];
    p.X_Coordinate__c = Decimal.valueOf(calcX).setScale(3, System.RoundingMode.HALF_UP);
    p.Y_Coordinate__c = Decimal.valueOf(calcY).setScale(3, System.RoundingMode.HALF_UP);
    pilesToUpdate.add(p);
}

// Boiler Piles: (1100.0, 2000.0) - Orthogonal foundation grid (Row-Column layout)
List<Pile__c> boilerPiles = [
    SELECT Id, Name, Pile_Identification_Number__c 
    FROM Pile__c 
    WHERE Construction_Package__r.Package_Type__c = 'Boiler Area'
    ORDER BY Pile_Identification_Number__c ASC
];

// 2x3 orthogonal grid for 6 boiler column piles
Double[][] boilerGrid = new Double[][]{
    new Double[]{1088.0, 1986.0},
    new Double[]{1098.0, 1986.0},
    new Double[]{1120.0, 1986.0},
    new Double[]{1130.0, 1986.0},
    new Double[]{1142.0, 1994.0},
    new Double[]{1165.0, 1986.0}
};

for (Integer i = 0; i < boilerPiles.size(); i++) {
    Integer idx = Math.min(i, boilerGrid.size() - 1);
    Pile__c p = boilerPiles[i];
    p.X_Coordinate__c = Decimal.valueOf(boilerGrid[idx][0]).setScale(3, System.RoundingMode.HALF_UP);
    p.Y_Coordinate__c = Decimal.valueOf(boilerGrid[idx][1]).setScale(3, System.RoundingMode.HALF_UP);
    pilesToUpdate.add(p);
}

// TG Island Piles: (1300.0, 2000.0) - Heavy machine deck longitudinal column lines
List<Pile__c> tgPiles = [
    SELECT Id, Name, Pile_Identification_Number__c 
    FROM Pile__c 
    WHERE Construction_Package__r.Package_Type__c = 'Turbine Generator (TG) Island'
    ORDER BY Pile_Identification_Number__c ASC
];

Double[][] tgGrid = new Double[][]{
    new Double[]{1286.0, 1990.0},
    new Double[]{1298.0, 1990.0},
    new Double[]{1310.0, 1990.0},
    new Double[]{1322.0, 1990.0},
    new Double[]{1330.0, 2002.0}
};

for (Integer i = 0; i < tgPiles.size(); i++) {
    Integer idx = Math.min(i, tgGrid.size() - 1);
    Pile__c p = tgPiles[i];
    p.X_Coordinate__c = Decimal.valueOf(tgGrid[idx][0]).setScale(3, System.RoundingMode.HALF_UP);
    p.Y_Coordinate__c = Decimal.valueOf(tgGrid[idx][1]).setScale(3, System.RoundingMode.HALF_UP);
    pilesToUpdate.add(p);
}

update pilesToUpdate;
System.debug('Updated ' + pilesToUpdate.size() + ' Piles with engineering coordinates.');


// -------------------------------------------------------------------------
// 2. UPDATE PEDESTALS
// -------------------------------------------------------------------------
List<Pedestal__c> pedestalsToUpdate = new List<Pedestal__c>();

// Boiler Column Pedestals (P-C1 to P-C8):
// P-C1 to P-C4 on Boiler Left Wing Raft R-1A
// P-C5 to P-C8 on Boiler Center Raft R-1B
Map<String, Double[]> boilerPedMap = new Map<String, Double[]>{
    'Boiler Column Pedestal P-C1' => new Double[]{1085.0, 1985.0},
    'Boiler Column Pedestal P-C2' => new Double[]{1095.0, 1985.0},
    'Boiler Column Pedestal P-C3' => new Double[]{1085.0, 1990.0},
    'Boiler Column Pedestal P-C4' => new Double[]{1095.0, 1990.0},
    'Boiler Column Pedestal P-C5' => new Double[]{1120.0, 1985.0},
    'Boiler Column Pedestal P-C6' => new Double[]{1135.0, 1985.0},
    'Boiler Column Pedestal P-C7' => new Double[]{1120.0, 1995.0},
    'Boiler Column Pedestal P-C8' => new Double[]{1135.0, 1995.0}
};

// TG Column Pedestals (TG-C1 to TG-C4) inside Condenser Pit / machine column lines
Map<String, Double[]> tgPedMap = new Map<String, Double[]>{
    'TG Column Pedestal TG-C1' => new Double[]{1296.0, 1992.0},
    'TG Column Pedestal TG-C2' => new Double[]{1312.0, 1992.0},
    'TG Column Pedestal TG-C3' => new Double[]{1296.0, 2002.0},
    'TG Column Pedestal TG-C4' => new Double[]{1312.0, 2002.0}
};

// GIS Gantry Support Pedestals (GIS-P1 to GIS-P4): Linear 400kV transmission gantry bay
Map<String, Double[]> swydPedMap = new Map<String, Double[]>{
    'GIS Gantry Support Pedestal GIS-P1' => new Double[]{1780.0, 1800.0},
    'GIS Gantry Support Pedestal GIS-P2' => new Double[]{1795.0, 1800.0},
    'GIS Gantry Support Pedestal GIS-P3' => new Double[]{1810.0, 1800.0},
    'GIS Gantry Support Pedestal GIS-P4' => new Double[]{1825.0, 1800.0}
};

for (Pedestal__c ped : [SELECT Id, Name FROM Pedestal__c]) {
    Double[] coords = null;
    if (boilerPedMap.containsKey(ped.Name)) {
        coords = boilerPedMap.get(ped.Name);
    } else if (tgPedMap.containsKey(ped.Name)) {
        coords = tgPedMap.get(ped.Name);
    } else if (swydPedMap.containsKey(ped.Name)) {
        coords = swydPedMap.get(ped.Name);
    }
    
    if (coords != null) {
        ped.X_Coordinate__c = Decimal.valueOf(coords[0]).setScale(3, System.RoundingMode.HALF_UP);
        ped.Y_Coordinate__c = Decimal.valueOf(coords[1]).setScale(3, System.RoundingMode.HALF_UP);
        pedestalsToUpdate.add(ped);
    }
}

update pedestalsToUpdate;
System.debug('Updated ' + pedestalsToUpdate.size() + ' Pedestals with engineering coordinates.');


// -------------------------------------------------------------------------
// 3. UPDATE RAFTS (Dynamic Industrial Geometries)
// -------------------------------------------------------------------------
List<Raft__c> raftsToUpdate = [
    SELECT Id, Name, Raft_Number__c, Construction_Package__r.Package_Type__c, Length_m__c, Width_m__c 
    FROM Raft__c
];

for (Raft__c raft : raftsToUpdate) {
    List<Map<String, Object>> points = new List<Map<String, Object>>();
    
    if (raft.Raft_Number__c == 'RFT-CHM-01') {
        // Chimney Annular Ring Raft: 16-corner regular polygon approximating the 42m circular foundation
        // Center: (1600.0, 2200.0), Radius: 21.0m (Length=42m, Width=42m)
        Integer corners = 16;
        for (Integer i = 1; i <= corners; i++) {
            Double angleRad = ((i - 1) * 2.0 * Math.PI) / corners;
            Double calcX = 1600.0 + 21.0 * Math.cos(angleRad);
            Double calcY = 2200.0 + 21.0 * Math.sin(angleRad);
            Decimal x = Decimal.valueOf(calcX).setScale(3, System.RoundingMode.HALF_UP);
            Decimal y = Decimal.valueOf(calcY).setScale(3, System.RoundingMode.HALF_UP);
            
            Map<String, Object> pt = new Map<String, Object>();
            pt.put('sequence', i);
            pt.put('x', x);
            pt.put('y', y);
            points.add(pt);
        }
        raft.Number_of_Corners__c = corners;
        raft.Coordinates_JSON__c = JSON.serialize(points);
        
    } else if (raft.Raft_Number__c == 'RFT-FGD-ABS1') {
        // FGD Absorber Tower Raft: 8-corner regular octagonal pad (cylindrical absorber shell)
        // Center: (1660.0, 2200.0), Radius: 11.0m (22m diameter)
        Integer corners = 8;
        for (Integer i = 1; i <= corners; i++) {
            Double angleRad = ((i - 1) * 2.0 * Math.PI) / corners;
            Double calcX = 1660.0 + 11.0 * Math.cos(angleRad);
            Double calcY = 2200.0 + 11.0 * Math.sin(angleRad);
            Decimal x = Decimal.valueOf(calcX).setScale(3, System.RoundingMode.HALF_UP);
            Decimal y = Decimal.valueOf(calcY).setScale(3, System.RoundingMode.HALF_UP);
            
            Map<String, Object> pt = new Map<String, Object>();
            pt.put('sequence', i);
            pt.put('x', x);
            pt.put('y', y);
            points.add(pt);
        }
        raft.Number_of_Corners__c = corners;
        raft.Coordinates_JSON__c = JSON.serialize(points);
        
    } else if (raft.Raft_Number__c == 'RFT-TG-01') {
        // TG Table Main Mat Slab (52m x 26m): Stepped 8-corner machine deck
        // Origin: (1280.0, 1985.0)
        Double[][] tgShape = new Double[][]{
            new Double[]{1280.0, 1985.0},
            new Double[]{1332.0, 1985.0},
            new Double[]{1332.0, 2003.0},
            new Double[]{1324.0, 2003.0},
            new Double[]{1324.0, 2011.0},
            new Double[]{1295.0, 2011.0},
            new Double[]{1295.0, 2003.0},
            new Double[]{1280.0, 2003.0}
        };
        for (Integer i = 0; i < tgShape.size(); i++) {
            Map<String, Object> pt = new Map<String, Object>();
            pt.put('sequence', i + 1);
            pt.put('x', tgShape[i][0]);
            pt.put('y', tgShape[i][1]);
            points.add(pt);
        }
        raft.Number_of_Corners__c = tgShape.size();
        raft.Coordinates_JSON__c = JSON.serialize(points);
        
    } else if (raft.Raft_Number__c == 'RFT-BLR-01A') {
        // Boiler Left Wing Raft R-1A (28.5m x 18m): 6-corner stepped foundation
        Double[][] blrShapeA = new Double[][]{
            new Double[]{1080.0, 1980.0},
            new Double[]{1108.5, 1980.0},
            new Double[]{1108.5, 1998.0},
            new Double[]{1095.0, 1998.0},
            new Double[]{1095.0, 1992.0},
            new Double[]{1080.0, 1992.0}
        };
        for (Integer i = 0; i < blrShapeA.size(); i++) {
            Map<String, Object> pt = new Map<String, Object>();
            pt.put('sequence', i + 1);
            pt.put('x', blrShapeA[i][0]);
            pt.put('y', blrShapeA[i][1]);
            points.add(pt);
        }
        raft.Number_of_Corners__c = blrShapeA.size();
        raft.Coordinates_JSON__c = JSON.serialize(points);
        
    } else if (raft.Raft_Number__c == 'RFT-BLR-01B') {
        // Boiler Center Raft R-1B (32m x 22m): 8-corner foundation with flue gas duct notch
        Double[][] blrShapeB = new Double[][]{
            new Double[]{1115.0, 1980.0},
            new Double[]{1147.0, 1980.0},
            new Double[]{1147.0, 2002.0},
            new Double[]{1138.0, 2002.0},
            new Double[]{1138.0, 1996.0},
            new Double[]{1124.0, 1996.0},
            new Double[]{1124.0, 2002.0},
            new Double[]{1115.0, 2002.0}
        };
        for (Integer i = 0; i < blrShapeB.size(); i++) {
            Map<String, Object> pt = new Map<String, Object>();
            pt.put('sequence', i + 1);
            pt.put('x', blrShapeB[i][0]);
            pt.put('y', blrShapeB[i][1]);
            points.add(pt);
        }
        raft.Number_of_Corners__c = blrShapeB.size();
        raft.Coordinates_JSON__c = JSON.serialize(points);
        
    } else if (raft.Raft_Number__c == 'RFT-BLR-01C') {
        // Boiler Right Wing Raft R-1C (28.5m x 18m): 6-corner stepped foundation
        Double[][] blrShapeC = new Double[][]{
            new Double[]{1155.0, 1980.0},
            new Double[]{1183.5, 1980.0},
            new Double[]{1183.5, 1992.0},
            new Double[]{1168.5, 1992.0},
            new Double[]{1168.5, 1998.0},
            new Double[]{1155.0, 1998.0}
        };
        for (Integer i = 0; i < blrShapeC.size(); i++) {
            Map<String, Object> pt = new Map<String, Object>();
            pt.put('sequence', i + 1);
            pt.put('x', blrShapeC[i][0]);
            pt.put('y', blrShapeC[i][1]);
            points.add(pt);
        }
        raft.Number_of_Corners__c = blrShapeC.size();
        raft.Coordinates_JSON__c = JSON.serialize(points);
        
    } else if (raft.Raft_Number__c == 'RFT-BLR-BB01') {
        // Bunker Bay Mat Slab BB-01 (45m x 12m): 4-corner rectangular strip
        Double[][] bbShape = new Double[][]{
            new Double[]{1080.0, 1960.0},
            new Double[]{1125.0, 1960.0},
            new Double[]{1125.0, 1972.0},
            new Double[]{1080.0, 1972.0}
        };
        for (Integer i = 0; i < bbShape.size(); i++) {
            Map<String, Object> pt = new Map<String, Object>();
            pt.put('sequence', i + 1);
            pt.put('x', bbShape[i][0]);
            pt.put('y', bbShape[i][1]);
            points.add(pt);
        }
        raft.Number_of_Corners__c = bbShape.size();
        raft.Coordinates_JSON__c = JSON.serialize(points);
        
    } else if (raft.Raft_Number__c == 'RFT-BLR-MILL1') {
        // Coal Mill Foundation Bay-1 (16m x 12m): 6-corner stepped foundation for bowl mill
        Double[][] millShape = new Double[][]{
            new Double[]{1055.0, 1960.0},
            new Double[]{1071.0, 1960.0},
            new Double[]{1071.0, 1972.0},
            new Double[]{1065.0, 1972.0},
            new Double[]{1065.0, 1968.0},
            new Double[]{1055.0, 1968.0}
        };
        for (Integer i = 0; i < millShape.size(); i++) {
            Map<String, Object> pt = new Map<String, Object>();
            pt.put('sequence', i + 1);
            pt.put('x', millShape[i][0]);
            pt.put('y', millShape[i][1]);
            points.add(pt);
        }
        raft.Number_of_Corners__c = millShape.size();
        raft.Coordinates_JSON__c = JSON.serialize(points);
        
    } else if (raft.Raft_Number__c == 'RFT-TG-COND') {
        // Condenser Pit Foundation (24m x 18m): 4-corner deep pit rectangle
        Double[][] condShape = new Double[][]{
            new Double[]{1292.0, 1988.0},
            new Double[]{1316.0, 1988.0},
            new Double[]{1316.0, 2006.0},
            new Double[]{1292.0, 2006.0}
        };
        for (Integer i = 0; i < condShape.size(); i++) {
            Map<String, Object> pt = new Map<String, Object>();
            pt.put('sequence', i + 1);
            pt.put('x', condShape[i][0]);
            pt.put('y', condShape[i][1]);
            points.add(pt);
        }
        raft.Number_of_Corners__c = condShape.size();
        raft.Coordinates_JSON__c = JSON.serialize(points);
        
    } else if (raft.Raft_Number__c == 'RFT-TG-BFP1') {
        // Boiler Feed Pump Foundation BFP-1 (14m x 8.5m): 4-corner pump pad
        Double[][] bfp1Shape = new Double[][]{
            new Double[]{1340.0, 1985.0},
            new Double[]{1354.0, 1985.0},
            new Double[]{1354.0, 1993.5},
            new Double[]{1340.0, 1993.5}
        };
        for (Integer i = 0; i < bfp1Shape.size(); i++) {
            Map<String, Object> pt = new Map<String, Object>();
            pt.put('sequence', i + 1);
            pt.put('x', bfp1Shape[i][0]);
            pt.put('y', bfp1Shape[i][1]);
            points.add(pt);
        }
        raft.Number_of_Corners__c = bfp1Shape.size();
        raft.Coordinates_JSON__c = JSON.serialize(points);
        
    } else if (raft.Raft_Number__c == 'RFT-TG-BFP2') {
        // Boiler Feed Pump Foundation BFP-2 (14m x 8.5m): 4-corner pump pad
        Double[][] bfp2Shape = new Double[][]{
            new Double[]{1340.0, 1998.0},
            new Double[]{1354.0, 1998.0},
            new Double[]{1354.0, 2006.5},
            new Double[]{1340.0, 2006.5}
        };
        for (Integer i = 0; i < bfp2Shape.size(); i++) {
            Map<String, Object> pt = new Map<String, Object>();
            pt.put('sequence', i + 1);
            pt.put('x', bfp2Shape[i][0]);
            pt.put('y', bfp2Shape[i][1]);
            points.add(pt);
        }
        raft.Number_of_Corners__c = bfp2Shape.size();
        raft.Coordinates_JSON__c = JSON.serialize(points);
        
    } else if (raft.Raft_Number__c == 'RFT-SWYD-GIS') {
        // GIS Substation Building Raft (60m x 20m): 4-corner elongated control building
        Double[][] gisShape = new Double[][]{
            new Double[]{1770.0, 1790.0},
            new Double[]{1830.0, 1790.0},
            new Double[]{1830.0, 1810.0},
            new Double[]{1770.0, 1810.0}
        };
        for (Integer i = 0; i < gisShape.size(); i++) {
            Map<String, Object> pt = new Map<String, Object>();
            pt.put('sequence', i + 1);
            pt.put('x', gisShape[i][0]);
            pt.put('y', gisShape[i][1]);
            points.add(pt);
        }
        raft.Number_of_Corners__c = gisShape.size();
        raft.Coordinates_JSON__c = JSON.serialize(points);
        
    } else if (raft.Raft_Number__c == 'RFT-SWYD-GT1') {
        // Generator Transformer GT-1 Mat (15m x 12m): 4-corner blast-wall contained plinth
        Double[][] gtShape = new Double[][]{
            new Double[]{1840.0, 1790.0},
            new Double[]{1855.0, 1790.0},
            new Double[]{1855.0, 1802.0},
            new Double[]{1840.0, 1802.0}
        };
        for (Integer i = 0; i < gtShape.size(); i++) {
            Map<String, Object> pt = new Map<String, Object>();
            pt.put('sequence', i + 1);
            pt.put('x', gtShape[i][0]);
            pt.put('y', gtShape[i][1]);
            points.add(pt);
        }
        raft.Number_of_Corners__c = gtShape.size();
        raft.Coordinates_JSON__c = JSON.serialize(points);
        
    } else if (raft.Raft_Number__c == 'PAT-RFT-BLR-A') {
        // Patratu Boiler Segment A (30m x 20m): 6-corner stepped raft
        Double[][] patShapeA = new Double[][]{
            new Double[]{2085.0, 2490.0},
            new Double[]{2115.0, 2490.0},
            new Double[]{2115.0, 2505.0},
            new Double[]{2105.0, 2505.0},
            new Double[]{2105.0, 2510.0},
            new Double[]{2085.0, 2510.0}
        };
        for (Integer i = 0; i < patShapeA.size(); i++) {
            Map<String, Object> pt = new Map<String, Object>();
            pt.put('sequence', i + 1);
            pt.put('x', patShapeA[i][0]);
            pt.put('y', patShapeA[i][1]);
            points.add(pt);
        }
        raft.Number_of_Corners__c = patShapeA.size();
        raft.Coordinates_JSON__c = JSON.serialize(points);
        
    } else if (raft.Raft_Number__c == 'PAT-RFT-BLR-B') {
        // Patratu Boiler Segment B (30m x 20m): 6-corner stepped raft (mirror)
        Double[][] patShapeB = new Double[][]{
            new Double[]{2120.0, 2490.0},
            new Double[]{2150.0, 2490.0},
            new Double[]{2150.0, 2510.0},
            new Double[]{2130.0, 2510.0},
            new Double[]{2130.0, 2505.0},
            new Double[]{2120.0, 2505.0}
        };
        for (Integer i = 0; i < patShapeB.size(); i++) {
            Map<String, Object> pt = new Map<String, Object>();
            pt.put('sequence', i + 1);
            pt.put('x', patShapeB[i][0]);
            pt.put('y', patShapeB[i][1]);
            points.add(pt);
        }
        raft.Number_of_Corners__c = patShapeB.size();
        raft.Coordinates_JSON__c = JSON.serialize(points);
    }
}

update raftsToUpdate;
System.debug('Updated ' + raftsToUpdate.size() + ' Rafts with industrial geometry coordinates.');
