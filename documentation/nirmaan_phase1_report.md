# NIRMAAN 2.0 — Phase 1 Deployment Report

> **Status**: Validation running against `NirmaanDev`. Awaiting results.
> **Generated**: 2026-10-23 | **API Version**: 67.0 | **CLI**: @salesforce/cli 2.147.7

---

## Files Created (62 total)

### Objects (7)
| Object | File |
|:---|:---|
| `Project__c` | `objects/Project__c/Project__c.object-meta.xml` |
| `Construction_Package__c` | `objects/Construction_Package__c/Construction_Package__c.object-meta.xml` |
| `Pile__c` | `objects/Pile__c/Pile__c.object-meta.xml` |
| `Raft__c` | `objects/Raft__c/Raft__c.object-meta.xml` |
| `Pedestal__c` | `objects/Pedestal__c/Pedestal__c.object-meta.xml` |
| `Daily_Progress_Log__c` | `objects/Daily_Progress_Log__c/Daily_Progress_Log__c.object-meta.xml` |
| `Inspection_Request__c` | `objects/Inspection_Request__c/Inspection_Request__c.object-meta.xml` |

### Custom Fields by Object

#### Project__c (8 fields)
| API Name | Type | Notes |
|:---|:---|:---|
| `Project_Code__c` | Text(20) | Unique, External ID, Required |
| `Status__c` | Picklist | 5 values, default=Planned |
| `Target_Start_Date__c` | Date | |
| `Target_End_Date__c` | Date | |
| `Actual_Start_Date__c` | Date | |
| `Actual_End_Date__c` | Date | |
| `Total_Budget__c` | Currency(18,2) | INR |
| `Project_Description__c` | LongTextArea(5000) | |

#### Construction_Package__c (10 fields)
| API Name | Type | Notes |
|:---|:---|:---|
| `Project__c` | **Master-Detail** to Project__c | Required, cascade delete |
| `Package_Type__c` | Picklist | 9 construction area types |
| `Status__c` | Picklist | 7 lifecycle stages |
| `Executing_Agency__c` | Text(100) | |
| `Total_Piles__c` | Roll-Up (COUNT) | All Pile__c children |
| `Completed_Piles__c` | Roll-Up (COUNT) | Filter: Pile Status = Completed |
| `Total_Rafts__c` | Roll-Up (COUNT) | All Raft__c children |
| `Completed_Rafts__c` | Roll-Up (COUNT) | Filter: Raft Status = Cast and Cured |
| `Total_Pedestals__c` | Roll-Up (COUNT) | All Pedestal__c children |
| `Completed_Pedestals__c` | Roll-Up (COUNT) | Filter: Pedestal Status = Handed Over for Structural Erection |

#### Pile__c (13 fields)
| API Name | Type | Notes |
|:---|:---|:---|
| `Construction_Package__c` | **Master-Detail** to Construction_Package__c | Required |
| `Pile_Identification_Number__c` | Text(40) | Unique, External ID, Required |
| `Pile_Diameter_mm__c` | Number(6,0) | Required |
| `Cut_Off_Level_m__c` | Number(8,3) | Design COL |
| `Founding_Depth_m__c` | Number(6,2) | |
| `Designed_Concrete_Volume_m3__c` | Number(8,2) | |
| `Actual_Concrete_Volume_m3__c` | Number(8,2) | |
| `Concrete_Grade__c` | Picklist | M25-M40, default=M35 |
| `Status__c` | Picklist | 8 lifecycle stages |
| `Drilling_Rig_ID__c` | Text(50) | |
| `Boring_Date__c` | Date | |
| `Concreting_Date__c` | Date | |
| `PIT_Test_Status__c` | Picklist | Pending/Passed/Defect Detected/Waived |

#### Raft__c (11 fields)
| API Name | Type | Notes |
|:---|:---|:---|
| `Construction_Package__c` | **Master-Detail** to Construction_Package__c | Required |
| `Raft_Number__c` | Text(40) | Required |
| `Length_m__c` | Number(6,2) | |
| `Width_m__c` | Number(6,2) | |
| `Depth_m__c` | Number(6,2) | |
| `Design_Concrete_Volume_m3__c` | **Formula** (Number) | Length x Width x Depth |
| `Concrete_Grade__c` | Picklist | M25-M45 |
| `Status__c` | Picklist | 10 lifecycle stages |
| `Target_Pour_Date__c` | Date | |
| `Actual_Pour_Date__c` | Date | |
| `Total_Rebar_Tonnage_MT__c` | Number(8,2) | |

#### Pedestal__c (8 fields)
| API Name | Type | Notes |
|:---|:---|:---|
| `Construction_Package__c` | **Master-Detail** to Construction_Package__c | Required |
| `Raft__c` | Lookup to Raft__c | Optional |
| `Grid_Reference__c` | Text(50) | Structural grid ref |
| `Height_m__c` | Number(6,2) | |
| `Cross_Section__c` | Text(50) | |
| `Status__c` | Picklist | 9 lifecycle stages |
| `Anchor_Bolt_Inspection__c` | Picklist | 3 states |
| `Handover_Date__c` | Date | |

#### Daily_Progress_Log__c (15 fields)
| API Name | Type | Notes |
|:---|:---|:---|
| `Construction_Package__c` | **Lookup** to Construction_Package__c | Required. Lookup (not M/D) prevents record-lock contention |
| `Project__c` | Lookup to Project__c | Required |
| `Pile__c` | Lookup to Pile__c | Optional |
| `Raft__c` | Lookup to Raft__c | Optional |
| `Pedestal__c` | Lookup to Pedestal__c | Optional |
| `Log_Date__c` | Date | Required, default=TODAY() |
| `Shift__c` | Picklist | Morning/Evening/Night |
| `Executing_Contractor__c` | Text(100) | |
| `Element_Type__c` | Picklist | Pile/Raft/Pedestal/General Civil |
| `Activity_Stage__c` | Picklist | 12 activity types |
| `Concrete_Quantity_Poured_m3__c` | Number(8,2) | |
| `Rebar_Erected_MT__c` | Number(8,2) | |
| `Manpower_Skilled__c` | Number(4,0) | |
| `Manpower_Unskilled__c` | Number(4,0) | |
| `Batching_Plant_Slip_Numbers__c` | Text(255) | |
| `Weather_Condition__c` | Picklist | 4 values |
| `Site_Engineer_Remarks__c` | LongTextArea(1000) | |
| `Verification_Status__c` | Picklist | 3 stages, field history tracked |

#### Inspection_Request__c (10 fields)
| API Name | Type | Notes |
|:---|:---|:---|
| `Pile__c` | Lookup to Pile__c | Optional |
| `Raft__c` | Lookup to Raft__c | Optional |
| `Pedestal__c` | Lookup to Pedestal__c | Optional |
| `Related_Element_Type__c` | Picklist | Required |
| `Stage__c` | Picklist | 7 inspection stages incl. Pour Card |
| `Status__c` | Picklist | 5 approval states |
| `Inspected_By__c` | Lookup to User | |
| `Inspection_Date__c` | Date | |
| `Compressive_Strength_MPa__c` | Number(5,2) | Cube test result |
| `Defect_Remarks__c` | LongTextArea(2000) | |

### Validation Rules (8)
| Object | Rule Name | Description |
|:---|:---|:---|
| Project__c | `End_Date_After_Start_Date` | Target End >= Target Start |
| Project__c | `Actual_End_Requires_Actual_Start` | Actual End requires Actual Start |
| Pile__c | `Concreting_Date_Requires_Boring_Complete` | Concreting Date >= Boring Date |
| Raft__c | `Actual_Pour_Date_Not_Before_Target` | Warns if pour > 30 days before target |
| Daily_Progress_Log__c | `DPR_Log_Date_Not_Future` | Log Date must be today or earlier |
| Daily_Progress_Log__c | `Concrete_Pour_Requires_Volume` | Requires positive volume when pouring |
| Inspection_Request__c | `Defect_Remarks_Required_On_Rejection` | Mandatory remarks on rejection/conditional |
| Inspection_Request__c | `Element_Lookup_Required_By_Type` | Correct element lookup per element type |

### Custom Tabs (7)
Projects, Construction Packages, Piles, Rafts, Pedestals, Daily Progress Logs, Inspection Requests

### Lightning Application
`NIRMAAN_2.app-meta.xml` — Lightning Standard nav app, landing on Projects tab, all 7 NIRMAAN tabs included.

### Permission Sets (3)
| Permission Set | Key Access |
|:---|:---|
| `Nirmaan_Project_Admin` | ViewAll + full CRUD on all 7 objects. No Modify All Data or View All Data granted. |
| `Nirmaan_Site_Engineer` | Read-only Projects/Packages; Create+Edit Piles/Rafts/Pedestals/DPR/RFI; No Delete. |
| `Nirmaan_Field_Supervisor` | Read-only all elements; Create+Edit DPR; Create-only RFI; No Delete. |

---

## Architectural Decisions

### Correct Design Decisions Made

1. **DPR uses Lookup, not Master-Detail to Construction_Package__c** — prevents Salesforce record-lock contention when multiple supervisors submit concurrent DPRs during shift handover for the same package.

2. **Roll-up filter picklist values exactly match deployed status values** — `Completed` (Pile), `Cast and Cured` (Raft), `Handed Over for Structural Erection` (Pedestal). These strings must remain identical in the target org.

3. **Per-element-type lookup fields on Inspection_Request__c** — Salesforce does not support polymorphic custom lookups in declarative metadata. The `Element_Lookup_Required_By_Type` validation rule enforces that the correct lookup is populated.

---

## Phase 2 Dependencies (Cannot Be Declarative)

| # | Constraint | Why Deferred to Phase 2 |
|:--|:---|:---|
| 1 | **Pour Card Quality Gate** — Pile/Raft/Pedestal status cannot change to Concreted without an Approved Pre-Pour Clearance RFI | Formula fields cannot query child records; cross-object VR only reads parent fields. **Solution**: Apex `BeforeUpdate` trigger |
| 2 | **DPR Project/Package consistency** — `Daily_Progress_Log__c.Project__c` must match `Construction_Package__c.Project__c` | Cannot cross Lookup-to-Master-Detail boundary in declarative formula. **Solution**: Apex trigger or Record-Triggered Flow |
| 3 | **Overall Project Progress %** — Requires a weighted percentage, not simple element count | Business weight definition still pending (count vs. volume vs. phase). **Solution**: Apex batch or aggregate service, post business decision |

---

## Sharing Model

| Object | OWD | Rationale |
|:---|:---|:---|
| Project__c | ReadWrite | All users see all projects. Tighten to Private + Sharing Rules if multi-org isolation needed |
| Construction_Package__c | ControlledByParent | Correct for Master-Detail |
| Pile__c, Raft__c, Pedestal__c | ControlledByParent | Correct for Master-Detail |
| Daily_Progress_Log__c | ReadWrite | All site staff see all DPRs |
| Inspection_Request__c | ReadWrite | All quality staff see all RFIs |

---

## Deployment Command (Run After Explicit Approval)

```powershell
sf project deploy start --source-dir force-app --target-org NirmaanDev --json
```

> [!CAUTION]
> Do not run this until you have reviewed the validation output above and explicitly approved. This will make live changes to the NirmaanDev org.
