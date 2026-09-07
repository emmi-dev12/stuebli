# IKEA Switzerland — bedroom starter catalog

Checked against official IKEA Switzerland product pages on 7 September 2026. Twelve specific variants, with assembled dimensions normalized to metres in [products.json](products.json). This is an initial catalog, not all IKEA furniture.

| Product and exact variant | Article number | Width × depth × height (cm) |
|---|---|---|
| [MALM High bed frame, white](https://www.ikea.com/ch/en/p/malm-bed-frame-high-white-s09929373/) | 099.293.73 | 176 × 209 × 100 |
| [TARVA Bed frame with LÖNSET, pine/Lönset](https://www.ikea.com/ch/en/p/tarva-bed-frame-pine-loenset-s29019481/) | 290.194.81 | 148 × 209 × 92 |
| [MALM Chest of 2 drawers, white](https://www.ikea.com/ch/en/p/malm-chest-of-2-drawers-white-80214549/) | 802.145.49 | 40 × 48 × 55 |
| [HEMNES Bedside table, grey-green/light brown stained](https://www.ikea.com/ch/en/p/hemnes-bedside-table-grey-green-light-brown-stained-50610739/) | 506.107.39 | 46 × 35 × 70 |
| [KLEPPSTAD Wardrobe with 3 doors, white](https://www.ikea.com/ch/en/p/kleppstad-wardrobe-with-3-doors-white-00441758/) | 004.417.58 | 117 × 55 × 176 |
| [PAX Wardrobe frame, white](https://www.ikea.com/ch/en/p/pax-wardrobe-frame-white-70458203/) | 704.582.03 | 99.8 × 58 × 201.2 |
| [MICKE Desk, white](https://www.ikea.com/ch/en/p/micke-desk-white-30213076/) | 302.130.76 | 73 × 50 × 75 |
| [MICKE Desk, white](https://www.ikea.com/ch/en/p/micke-desk-white-80213074/) | 802.130.74 | 105 × 50 × 75 |
| [MARKUS Office chair, Vissle dark grey](https://www.ikea.com/ch/en/p/markus-office-chair-vissle-dark-grey-70261150/) | 702.611.50 | 62 × 60 × 140 |
| [MALM Chest of 3 drawers, white](https://www.ikea.com/ch/en/p/malm-chest-of-3-drawers-white-20403562/) | 204.035.62 | 80 × 48 × 78 |
| [BILLY Bookcase, white](https://www.ikea.com/ch/en/p/billy-bookcase-white-00263850/) | 002.638.50 | 80 × 28 × 202 |
| [KALLAX Shelving unit, white](https://www.ikea.com/ch/en/p/kallax-shelving-unit-white-80275887/) | 802.758.87 | 76.5 × 39 × 146.5 |

## What is verified

Product identity, market, finish and dimensions were checked against the official pages linked above. The values describe assembled products; package sizes and nominal marketing sizes are excluded from placement dimensions. Access date records this research session; web source content may be cached. Store stock, delivery availability and price are not verified.

## Modeling details that matter

- MALM 160×200 describes the mattress. Its frame occupies 176×209 cm. Frame and mattress dimensions are separate fields.
- TARVA height is mapped from its published headboard height; bed length maps to scene depth.
- PAX is 99.8×58×201.2 cm, despite its 100×58×201 label. This entry is a frame, not a complete wardrobe. The listed minimum ceiling for upright assembly is 202 cm; adding sliding doors requires 205 cm.
- KALLAX is 76.5×39×146.5 cm, despite its 77×147 label. The stored orientation is upright.
- MARKUS height adjusts from 129 to 140 cm. The catalog envelope uses the maximum, without claiming to cover reclining or swivel motion.
- MALM three-drawer chest publishes a 27 cm drawer pull-out. Interior drawer depth on other products must not be treated as travel.
- Null movement or anchoring values mean unknown/not recorded, never zero clearance or confirmation that anchoring is unnecessary. See the linked assembly instructions before modeling installation.
- Both MICKE pages display “Now or never”; avoid treating these as permanent catalog inventory.

## Asset status

These are sourced product records, not verified 3D meshes. No IKEA photographs, textures, assembly PDFs or meshes are bundled. Product-page links provide visual and assembly references. Asset redistribution rights have not been established; official photorealistic models have not been obtained. Any procedural model built from this catalog must be labeled as an approximation until its shape and moving parts are separately checked.

## Integration boundary

The app now preserves catalog IDs, exposes official sources, and locks product dimensions. The bundled copy in Sources/StubliCore/Resources/ikea-ch.json must match products.json. Procedural meshes are approximate and separate from product verification. The explicit Make custom action detaches catalog identity before resizing.

## Expansion workflow

For each new variant, open its Swiss product page, record its exact article number and finish, inspect the assembled dimensions, record the source and access date, then check any assembly/movement requirements. Keep unavailable measurements explicitly unknown. Product revisions and other countries require separate verification.
