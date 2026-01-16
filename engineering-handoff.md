### Stage 1: CX Team Actions

**Epicor Update:**

- Quote #Q-2026-0142 converted to Order #SO-2026-0089
- Ship date: March 15, 2026
- Payment terms: Net 30

**Documents Uploaded:**

- `SoFi_Site_Survey_Jan2026.pdf` (electrical room photos, existing panel specs)
- `SoFi_Approved_Quote_v3.xlsx` (final pricing with customer signature)
- `Drawing_Approval_Email_MarcusChen.pdf`

**Salesforce Handoff Record Created:**

| Field | Value |
| --- | --- |
| Product Line(s) | Entertainment Power, Reefer |
| Application | Entertainment Venue |
| Voltage | 480V 3-phase (main); 208V (reefer drops) |
| Amperage | 1200A main distribution; 60A per reefer outlet (×24) |
| Enclosure | NEMA 3R (outdoor rated, weather protected) |
| Connector Type | Cam-lok (entertainment); Pin & sleeve (reefer) |
| Site Conditions | Outdoor loading dock, coastal environment, space-constrained electrical room |
| Customer Intent | "Stadium wants unified power distribution for touring shows + 24 reefer connections for catering vendors. Future expansion to 36 reefer outlets mentioned. Marcus emphasized reliability—no downtime during events." |

---

### Stage 2: Engineering Team Actions

**Handoff Package Review (LWC Display):**

```
┌─────────────────────────────────────────────────────────────────┐
│  ENGINEERING INTAKE: SoFi Stadium                               │
├─────────────────────────────────────────────────────────────────┤
│  CUSTOMER CONTEXT                                               │
│  Account: SoFi Stadium | Prior Orders: 0 (new customer)         │
│  Contact: Marcus Chen, Facilities Director                      │
│  Industry: Entertainment Venue                                  │
├─────────────────────────────────────────────────────────────────┤
│  SPEC SUMMARY                                                   │
│  ┌──────────────┬──────────────┬─────────────┬────────────────┐ │
│  │ Voltage      │ Amperage     │ Enclosure   │ Connectors     │ │
│  ├──────────────┼──────────────┼─────────────┼────────────────┤ │
│  │ 480V 3-ph    │ 1200A main   │ NEMA 3R     │ Cam-lok (ent)  │ │
│  │ 208V (reefer)│ 60A × 24     │             │ Pin/sleeve (rf)│ │
│  └──────────────┴──────────────┴─────────────┴────────────────┘ │
├─────────────────────────────────────────────────────────────────┤
│  SALES NOTES                                                    │
│  "Future expansion to 36 reefer outlets mentioned."             │
│  "Marcus emphasized reliability—no downtime during events."     │
├─────────────────────────────────────────────────────────────────┤
│  APPLICABLE SOPs                                                │
│  📘 ShowSwitch Design Standards (Entertainment Power)           │
│  📘 Multi-Circuit Reefer Layout Guidelines                      │
│  📘 NEMA 3R Enclosure Specifications                            │
│  📘 Coastal Environment Corrosion Protection                    │
└─────────────────────────────────────────────────────────────────┘
```

**Engineering Actions:**

| Step | Action | Status |
| --- | --- | --- |
| Review memos | Noted: customer wants future expansion capability | ✓ |
| Missing docs? | Requested: electrical room single-line diagram | ⏳ Pending |
| BOM created | ShowSwitch 1200A unit + 24-circuit reefer panel | ✓ |
| Drawings | SoFi-2026-0089-E01 (main), SoFi-2026-0089-E02 (reefer) | ✓ |
| BOM labeled | "Ready to Buy" | ✓ |
| Peer review assigned | Assigned to: Sarah Torres | ✓ |

**Peer Review (HOP Checklist):**

| Checklist Item | Result |
| --- | --- |
| Voltage/amperage matches quote | ✓ Pass |
| Connector types per product line standards | ✓ Pass |
| Enclosure rating appropriate for environment | ✓ Pass |
| BOM completeness | ⚠️ Flag: Add marine-grade hardware (coastal location) |
| Drawings match BOM | ✓ Pass |
| Future expansion accounted for | ⚠️ Flag: Design panel with 36-slot capacity, populate 24 |

**Engineering Notes Added:**

> "Per peer review: Upgrading to marine-grade stainless hardware due to coastal salt air. Designing reefer panel with 36-slot capacity (24 populated) per customer's expansion mention. Increases BOM cost by $4,200—PM to confirm with customer."
>