# GP2GP — Research Notes

> Researched 27 March 2026 from the local MIM 7.2.02 repository and web-archived
> earlier MIM versions at the National Archives.

---

## 1. What is GP2GP?

GP2GP is an NHS messaging standard that enables the electronic transfer of a
patient's **Electronic Healthcare Record (EHR)** between GP practices when a
patient re-registers.
Before GP2GP, records travelled as paper summaries, causing delays and gaps in
care.  The system is still live (as of 2026) despite being based on specifications
that have not been substantially revised since ~2007.  New GP system suppliers
are required to implement it from these archaic specs.

---

## 2. NHS England open-source GP2GP adaptors

Because raw HL7v3 parsing is extremely difficult, NHS England has published
production-quality open-source adaptors that handle the heavy lifting.  Both
are **Java Spring Boot** applications released as Docker images, dual-licensed
MIT/OGL (Crown Copyright).  They are actively maintained and in production use
by New Market Entrant (NME) GP system suppliers.

### GP2GP Sending Adaptor (sending-practice side)

> GitHub: <https://github.com/NHSDigital/integration-adaptor-gp2gp-sending>
> DockerHub: [nhsdev/nia-gp2gp-adaptor](https://hub.docker.com/r/nhsdev/nia-gp2gp-adaptor)

Translates **FHIR → HL7v3 EhrExtract**.  The old practice deploys this; it
reads the patient record from a GP Connect FHIR API and produces the HL7v3
`RCMR_IN030000UK08` EHR Extract message for transmission via Spine.

### GP2GP Requesting Adaptor (receiving-practice side)

> GitHub: <https://github.com/NHSDigital/integration-adaptor-gp2gp-requesting>
> DockerHub: [nhsdev/nia-ps-adaptor](https://hub.docker.com/r/nhsdev/nia-ps-adaptor) (translator) + [nhsdev/nia-ps-facade](https://hub.docker.com/r/nhsdev/nia-ps-facade) (facade)

Translates **HL7v3 EhrExtract → FHIR bundle**.  The new practice deploys this;
it issues the GP2GP request, receives the incoming HL7v3 extract, and converts
it to a FHIR STU3 bundle that the receiving system can consume.  The key
component is the `gp2gp-translator` submodule.

### Mapping documentation

A separate repo documents how GP2GP concepts map to FHIR and vice versa:
<https://github.com/NHSDigital/patient-switching-adaptors-mapping-documentation>

### Offline / stand-alone use

Both adaptors normally require full Spine connectivity (HSCN, CIS2, MHS
adaptor).  However, the requesting adaptor ships a **stand-alone Gradle task**
that runs the `gp2gp-translator` against a local EhrExtract XML file and
outputs a FHIR bundle — no Spine connection needed.  This is useful for
development and testing against synthetic or anonymised extract files.

---

## 3. Where the specification lives

The canonical specification is the **NHS National Programme for IT (NPfIT)
Message Implementation Manual (MIM)**.  The MIM is a multi-volume HTML
publication issued under the document number **NPFIT-FNT-TO-DPM-0724**.

Key MIM versions that contain meaningful GP2GP changes:

| MIM version | Issue date | GP2GP domain version | Notes |
|---|---|---|---|
| 3.1.09 | 14 Jan 2005 | ~1.7–1.8 | Minor changes; P1R2 (Build 3) release |
| 4.2.00 | 31 Oct 2006 | **1.9** (no changes from 4.1.x) | 2006B2 Spine release; GP2GP unchanged |
| 5.1.x | ~2006 | **2.0 / 2.1** | Major EhrExtract restructure; PMIP date support |
| 6.3.01 | 08 Jan 2008 | **2.2** | Minor (XML example reorganisation) |
| 7.2.02 | (latest, not archived) | **2.2** | Final issued version; in this repo |

> **Key point:** the MIM uses a "delta" publishing model.  Each release only
> documents what changed.  To understand the full GP2GP spec you must read the
> domain IM document (`GP2GP IM.htm`) from the _latest_ MIM that contains a
> substantive version — effectively MIM 5.x–6.x introduced the 2.0 message and
> MIM 6.3.01 / 7.2.02 carry the final v2.2 text.

The local copy of the final spec is at:

```
Domains/GP2GP/Document files/GP2GP IM.htm          ← main IM
Domains/GP2GP/Document files/EhrExtractGuide.htm   ← detailed implementer guide
Domains/GP2GP/Document files/changelog.htm         ← version-by-version changes
Domains/GP2GP/Tabular View/                        ← per-element tabular specs
Domains/GP2GP/Document files/M*.htm                ← medication structures
Domains/GP2GP/Document files/O*.htm                ← observation structures
Domains/GP2GP/Document files/X*.htm                ← other statement structures
Schemas/RCMR_IN010000UK06.xsd                      ← EHR Request interaction schema
Schemas/RCMR_IN030000UK08.xsd                      ← EHR Extract interaction schema
```

---

## 4. High-level message flow

The entire interaction is just **two HL7 v3 messages** (plus infrastructure
acknowledgements):

```
New GP practice                              Old GP practice
(EHR Requester)                          (EHR Request Fulfiller)
       |                                          |
       |--- RCMR_IN010000UK06 (EHR Request) ----> |
       |                                          |
       | <-- MCCI_IN010000UK13 (App Ack) -------- |
       |                                          |
       |          [manual review at old practice] |
       |                                          |
       | <-- RCMR_IN030000UK08 (EHR Extract) ---- |
       |                                          |
       |--- MCCI_IN010000UK13 (App Ack) --------> |
```

### Trigger

A patient registers at a new GP practice.  The new system:

1. Queries **PDS** (Patient Demographic Service) to find the patient's previous
   practice.
2. Queries **SDS** (Spine Directory Services) to confirm the old system is
   GP2GP-capable.
3. Sends the EHR Request; the old practice has **24 hours** to respond with the
   extract.

### Application roles

| Role | HL7 ID | Description |
|---|---|---|
| EHR Requester | `RCMR_AR010000UK01` | New practice initiating the transfer |
| EHR Request Fulfiller | `RCMR_AR020000UK01` | Old practice providing the record |

### Assumptions baked into the spec

- Anonymity of the requesting practice does not need to be preserved.
- Manual sign-off is required at the old practice before the extract is sent.
- External documents (e.g. scanned letters) can be sent either as MIME
  attachments or inline in the EHR Extract via TMS.
- The SDS stores enough device metadata that only a SDS device ID is needed in
  the extract.

---

## 5. Message definitions

### 4.1 EHR Request — `RCMR_MT010101UK03`

Sent by: new practice → old practice (via `RCMR_IN010000UK06`)

A minimal message asking for the patient's EHR.  Wrapping:

- **Transmission wrapper:** `MCCI_MT010101UK12` (Send Message Payload)
- **Control Act wrapper:** `MCAI_MT040101UK03` (Control Act — Action)

### 4.2 EHR Extract — `RCMR_MT030101UK06`

Sent by: old practice → new practice (via `RCMR_IN030000UK08`)

This is the bulk of the specification.  The extract is a hierarchical HL7 v3
document with the following structure:

```
EhrExtract
  ├── author          (sending system / organisation; digitally signed)
  ├── destination     (intended recipient organisation)
  ├── recordTarget    (the patient, identified by NHS number)
  ├── limitation      (EhrExtractSpecification — scope, always "entire record")
  └── EhrFolder [1..*]
        ├── author    (provenance of this folder's data; digitally signed)
        ├── responsibleParty [AgentRole, ...] (role directory)
        └── EhrComposition [1..*]
              ├── author
              ├── participant [...]
              └── EhrStatement [1..*]
                    (ObservationStatement | NarrativeStatement |
                     MedicationStatement | RequestStatement |
                     PlanStatement | RegistrationStatement |
                     CompoundStatement | LinkSet | ...)
```

#### EhrFolder — provenance tracking across transfers

Folders allow the record to carry provenance across _chains_ of transfers:

- Practice A → B: extract has **1 folder** (A's own data).
- Practice B → C: extract has **2 folders** (A's original folder + B's new data).
- Practice C → D: **3 folders**, and so on.

Entries in one folder _may_ reference/revise entries in another folder.

#### EhrComposition — the consultation unit

A composition represents a discrete authoring transaction with the record —
roughly equivalent to a single consultation or encounter note.  Types include:

- Single consultation (face-to-face, telephone, home visit, etc.)
- Series of indistinguishable consultations
- Actions outside a consultation (repeat prescriptions, filing reports, referrals)
- Computer-generated entries (decision support, summaries, legacy data imports)
- Problem-oriented link sets

Compositions are named using a controlled vocabulary (`EhrCompositionName`),
e.g. "Surgery Consultation Note", "Discharge Report", "Repeat Issue Note",
"Laboratory Result".

---

## 6. Clinical statement types

All clinical content inside an `EhrComposition` is represented using these
statement classes:

### ObservationStatement
The workhorse — used for coded clinical events that actually occurred:
- Clinical/social history, symptoms, examination findings
- Diagnoses and clinical problems
- Investigation results (with reference ranges via `InterpretationRange`)
- Allergies
- Surgical history

Key attributes: `code` (Read Code / SNOMED CT / NHS CT3), `value` (result),
`effectiveTime` (when it happened), `participant.time` (when recorded).

### NarrativeStatement
Free text that cannot be reliably coded.  Content is carried in an `ED`
(Encapsulated Data) field as plain text, fixed-font text (PMIP-style), or
restricted XHTML (defined in `EhrXhtml.htm`).

### MedicationStatement + EhrSupply
Structured representation of prescribing:

| Sub-type | Meaning |
|---|---|
| `Authorise` | Repeat authorisation |
| `Prescribe` | Issued prescription (one-off or repeat issue) |
| `Discontinue` | Cancellation/discontinuation |

Supports: one-off prescriptions, repeat authorisations + individual issues,
cancellation, supply and administration.

### RequestStatement / PlanStatement
Referrals, investigation requests, and future planned actions.

### RegistrationStatement
Patient registration info, usual GP, next-of-kin, carers.

### CompoundStatement
Nested container for grouping related statements:
- **Topic** (`classCode="Topic"`) — non-semantic organiser (e.g. "Allergy topic")
- **Category** (`classCode="Category"`) — SOAP headings (History, Exam, etc.)
- **Battery** — collection of result items (e.g. full blood count)
- **Cluster** — broader nested template-style grouping

### LinkSet
Problem-orientation links between statements across the record.

---

## 7. Coding schemes

The spec supports multiple clinical coding systems simultaneously:

| Scheme | Representation |
|---|---|
| Read Code v2 | 5 characters (pad to 5 with trailing `.`; 4-byte codes prefixed `.`) |
| Read Code v2 + Term Code | 7-character combined code |
| NHS Clinical Terms v3 (CTV3) | Code + Term Id |
| SNOMED Clinical Terms | Concept Id; OID `2.16.840.1.113883.2.1.3.2.4.15` |

At most one coded translation per attribute is permitted.  Original text
(`originalText`) must always be included alongside codes.

---

## 8. Identifiers

Two types:

- **External instance identifiers** — use HL7 `II` type with `root` (OID of the
  scheme) + `extension` (the actual identifier, e.g. NHS number).
- **Internal instance identifiers** — DCE UUID in `root` only, generated fresh
  for every element instance; must be stored by receiving systems to support
  cross-references and future updates.

---

## 9. Attachments

Any `EhrStatement` can reference an `ExternalDocument`:

- **Reference to external resource** — URL in the `ED` datatype's `reference`
  child; classified with `EhrAttachmentCode`.
- **Inline attachment** — binary data (base64 or XML) in `ExternalDocument.text`.

Supported formats: HTML, PDF (preferred for documents), XML EDI messages (inline
as XML, not base64), scanned images.

---

## 10. Version history of the GP2GP domain spec

| Version | Date | Key changes |
|---|---|---|
| 1.0 | 10 May 2004 | First issue |
| 1.3 | 03 Sep 2004 | New generic Control Act Wrapper; SDS OIDs; updated Agent SDS CMETs |
| 1.6 | 06 Dec 2004 | CR MIM-CR-0272 |
| 1.7 | 07 Jan 2005 | CRs MIM-CR-0146, 0235, 0274, 0296, DACM-CR-54 |
| 1.8 | 09 Mar 2005 | CRs MIM-CR-0303, 0442–0450 |
| 1.9 | 30 Sep 2005 | CR MIM-CR-0614: correct SNOMED OID in tabular view |
| **2.0** | 28 Feb 2006 | **Major restructure of EhrExtract.** Agent Directory re-modelled. `EhrFolder.author` CMET changed. `EhrStatementCategory` added. `Material.lotnumberText` added. `NarrativeStatement.code` enabled. PMIP date support (6 new date fields mapped). `EhrComposition@id` multiplicity raised to `[1..2]` for PMIP report ID. |
| 2.1 | 31 May 2006 | Fix spelling `SpecimenInvestigtaion2` → `SpecimenInvestigation2`; fix 2.0 changelog |
| **2.2** | 22 Mar 2007 | Reorganise location of XML example files (**final version**) |

---

## 11. Infrastructure dependencies

GP2GP does not stand alone — it depends heavily on:

- **PDS** (Patient Demographic Service) — to find the patient's previous practice
- **SDS** (Spine Directory Services) — to discover GP2GP capability and obtain
  device/system metadata; OIDs per SDS identifier type are used throughout
- **TMS** (Transport/Message Service) — carries the actual HL7 payloads (SOAP
  over HTTP/S via Spine); large EHR Extracts with attachments are sent through TMS
- **Infrastructure domain** (MIM section) — defines the Transmission Wrapper
  (`MCCI_MT010101UK12`), Control Act Wrapper (`MCAI_MT040101UK03`), and
  Application Acknowledgement (`MCCI_IN010000UK13`)

---

## 12. Implementer pain points and notable quirks

1. **Spec opacity.** The MIM is published as a tree of HTML files with embedded
   bitmaps and cross-links.  The tabular view (`.htm` files in `Tabular View/`)
   defines per-element cardinality and defaults but is not machine-readable.

2. **Delta publishing.** Early MIM versions introduced GP2GP; later versions
   carry the same domain IM basically unchanged.  You must use the _latest_
   domain IM version (2.2 from MIM 6.3.01 / 7.2.02) as the authoritative text,
   treating all earlier versions as superseded.

3. **Manual process required.** The spec explicitly assumes a human at the old
   practice must review and release the extract before it is sent.  There is no
   automated rejection pathway in the message design (only an App Ack).

4. **PMIP mapping.** A separate document (`PMIP_Mapping.htm`) maps NHS Pathology
   Messaging Implementation Project (PMIP) fields into GP2GP structures — a
   sign of significant complexity in representing lab results.

5. **Folder chain accumulation.** As a patient moves between practices, the
   EhrExtract grows a new folder each time.  Receiving systems must handle
   arbitrarily deep folder nesting.  Cross-folder references (revisions,
   corrections) add further complexity.

6. **No structured rejection.** There is no specified message for "I cannot
   send this record".  Failures are handled via the infrastructure Dead Letter
   Queue, with out-of-band manual resolution.

7. **Coding heterogeneity.** The spec permits Read v2, CTV3, SNOMED CT, and free
   text, often simultaneously in the same message.  Receiving systems must cope
   with all of these.

8. **IE6-era HTML.** The original MIM was designed for Internet Explorer 6 at
   1024×768.  The local files in this repo are Windows-1252 encoded HTML.

---

## 13. Local artefacts in this repository (MIM 7.2.02)

| Path | Contents |
|---|---|
| `Domains/GP2GP/Document files/GP2GP IM.htm` | Main domain IM (v2.2) |
| `Domains/GP2GP/Document files/EhrExtractGuide.htm` | Detailed implementer guide |
| `Domains/GP2GP/Document files/changelog.htm` | Full version changelog |
| `Domains/GP2GP/Document files/PMIP_Mapping.htm` | PMIP↔GP2GP field mapping |
| `Domains/GP2GP/Document files/M1–M8_*.htm` | Medication statement guidance |
| `Domains/GP2GP/Document files/O1,O3–O5_*.htm` | Observation guidance |
| `Domains/GP2GP/Document files/X1,X2,X4–X6_*.htm` | Other statements |
| `Domains/GP2GP/Document files/S1–S3_*.htm` | Statement ID/status/revision, agents, subjects |
| `Domains/GP2GP/Document files/EhrXhtml.htm` | Restricted XHTML subset for narratives |
| `Domains/GP2GP/Tabular View/RCMR_HD030100UK06-NoEdit.htm` | EhrExtract tabular view |
| `Domains/GP2GP/Tabular View/RCMR_HD010100UK03-NoEdit.htm` | EhrRequest tabular view |
| `Domains/GP2GP/Tabular View/RCMR_RM030000UK06.htm` | EhrExtract R-MIM diagram |
| `Schemas/RCMR_IN010000UK06.xsd` | EHR Request interaction schema |
| `Schemas/RCMR_IN030000UK08.xsd` | EHR Extract interaction schema |

---

## 14. Web-archived earlier MIM versions

Useful for historical context (all via National Archives):

- **MIM 3.1.09** (Jan 2005): https://webarchive.nationalarchives.gov.uk/ukgwa/20250306135910/https:/data.developer.nhs.uk/dms/mim/3.1.09/Index.htm
- **MIM 4.2.00** (Oct 2006): https://webarchive.nationalarchives.gov.uk/ukgwa/20250306140715/https:/data.developer.nhs.uk/dms/mim/4.2.00/Index.htm
- **MIM 6.3.01** (Jan 2008): https://webarchive.nationalarchives.gov.uk/ukgwa/20250306140946/https:/data.developer.nhs.uk/dms/mim/6.3.01/Index.htm
