# Application Context: GST Filing and Invoice Management App

## Overview

This application facilitates GST filing and invoice management. It allows users to add parties, generate invoices, and prepare GST reports. The application follows a structured flow to ensure compliance with GST norms, including handling multiple party types, transaction types, and GST sections.

---

## Core Features

1. **Party Management**

   - Add, edit, and delete party details.
   - Classify parties as:
     - Unregistered
     - Registered - Regular
     - Registered - Composite
   - Track party-specific details like reverse charge applicability (RCN).

2. **Invoice Management**

   - Create invoices for different transaction types:
     - B2B (Business-to-Business)
     - B2C (Business-to-Consumer)
     - SEZ Supplies
     - Exempt Supplies
     - Deemed Exports
   - Automatically calculate applicable taxes (CGST, SGST, IGST).
   - Include credit and debit note management for invoice adjustments.

3. **GST Report Generation**

   - Generate GST1 report with 19 sections:
     - B2B, B2C Small, B2C Large
     - CDNR (Credit/Debit Note Registered), CDNUR (Credit/Debit Note Unregistered)
     - HSN Summary, Documents Issued
     - EXP (Exports), AT (Advances Received), ATADJ (Advance Adjustments)
     - Other categories per GST norms
   - Automate classification of invoices into relevant sections.

4. **Tax Calculation**
   - Automatically calculate GST based on:
     - Party type
     - Transaction type
     - Product HSN/SAC code
   - Ensure accurate tax computation for intra-state and inter-state supplies.

---

## Application Flow

### 1. Home Screen

- **Features**:
  - View a summary of parties, invoices, and pending tasks.
  - Buttons for:
    - Adding a party
    - Adding an invoice
    - Generating GST reports

### 2. Add Party Screen

- **Details to Input**:

  - Party Name
  - Party Type:
    - Unregistered
    - Registered - Regular
    - Registered - Composite
  - Reverse Charge (RCN): Applicable for unregistered parties.
  - GSTIN (if registered)
  - Address and contact details

- **Validation**:

  - If unregistered, enable RCN toggle.
  - If registered, hide RCN toggle.

- **Save Party**:
  - Save party details into the database.

### 3. Add Sales Invoice Screen

- **Steps**:

  1. Select Party from the list.
  2. Select Invoice Type:
     - Regular B2B
     - SEZ Supplies (with or without payment)
     - Deemed Export
     - Intra-State Supplies Attracting IGST
  3. Add Products/Items:
     - Product Name
     - HSN Code
     - Quantity
     - Rate per unit
     - Tax rate (GST)
  4. Calculate taxes:
     - Automatically compute CGST/SGST or IGST based on party location and type.
  5. Add Invoice Details:
     - Invoice Number
     - Date
     - Payment Due Date
     - Billing & Shipping Address

- **Save Invoice**:
  - Save invoice details into the database for further processing.

### 4. Generate GST Report

- **Steps**:

  1. Collect all invoices.
  2. Classify invoices into the following categories:
     - **B2B**: Registered parties with GSTIN.
     - **B2C Small (B2CS)**: Unregistered parties with invoice value below the threshold.
     - **B2C Large (B2CL)**: Unregistered parties with invoice value above the threshold.
     - **CDNR/CDNUR**: Credit/Debit notes for registered/unregistered parties.
     - **EXP**: Export invoices.
     - **HSN Summary**: Summary of all HSN codes with aggregated values.
     - **Exempt**: Invoices with no GST applicable.
  3. Compile all data into a CSV format.
  4. Provide a downloadable GST1 report.

- **Validation**:
  - Ensure all required fields are filled before report generation.

---

## Detailed Data Flow

### Party Classification

- **Unregistered**:

  - No GSTIN.
  - Reverse Charge (RCN) may apply.
  - Invoices typically go to the **B2C** section.

- **Registered**:
  - GSTIN required.
  - Invoices go to the **B2B** section.

### Invoice Classification

1. **B2B Invoices**:

   - For registered parties.
   - Includes SEZ supplies with or without payment.

2. **B2C Invoices**:

   - For unregistered parties.
   - Classified into small (B2CS) or large (B2CL) based on invoice value threshold.

3. **HSN Summary**:

   - Aggregates all HSN codes with their corresponding taxable values and tax amounts.

4. **Credit/Debit Notes**:
   - Separate sections for registered and unregistered parties (CDNR/CDNUR).

### Tax Calculation

- **Intra-State Supplies**:

  - Split into CGST and SGST.

- **Inter-State Supplies**:
  - Charge IGST.

### Report Structure

1. **Header Information**:
   - GSTIN of the main user.
   - Filing period.
2. **Sections**:
   - 19 sections as per GST norms.
3. **HSN Summary**:
   - List of items grouped by HSN codes.
4. **Documents Issued**:
   - Summary of issued invoices, credit notes, debit notes, etc.

---

## Technical Details

### Database Schema

1. **Parties**:

   - `partyId`
   - `name`
   - `type` (Unregistered, Registered-Regular, Registered-Composite)
   - `isRCN`
   - `GSTIN`
   - `address`

2. **Invoices**:

   - `invoiceId`
   - `partyId`
   - `type` (B2B, B2C, SEZ, etc.)
   - `date`
   - `items` (array of product details)
   - `totalValue`
   - `taxBreakup` (CGST, SGST, IGST)

3. **HSN Summary**:

   - `hsnCode`
   - `description`
   - `quantity`
   - `taxableValue`
   - `totalTax`

4. **Credit/Debit Notes**:
   - `noteId`
   - `partyId`
   - `invoiceId`
   - `type` (Credit/Debit)
   - `value`

### APIs

1. **Add Party**

   - Endpoint: `POST /api/parties`
   - Payload: Party details

2. **Add Invoice**

   - Endpoint: `POST /api/invoices`
   - Payload: Invoice details

3. **Generate GST Report**
   - Endpoint: `GET /api/reports/gst1`
   - Response: CSV file of GST1 report

---

## Next Steps

1. Implement UI for:
   - Add Party
   - Add Sales Invoice
   - Generate GST Report
2. Set up backend APIs to handle:
   - Data storage
   - Report generation
3. Integrate tax calculation logic based on party and transaction type.
4. Test the GST report for compliance with government norms.

---

# GST App V2 Project Context

## Current Implementation Status

### 1. Authentication

- [x] Firebase Authentication
- [x] User sign-in/sign-out
- [x] Basic profile display
- [x] User session management

### 2. Store Management

- [x] Store selection via drawer
- [x] Store provider implementation
- [x] Store-specific data filtering
- [x] Store context persistence

### 3. Core Features

#### Homepage

- [x] Balance section
- [x] Quick actions menu
- [x] Recent transactions list
- [x] Basic analytics display
- [x] Navigation drawer
- [x] Bottom navigation

#### Party Management

- [x] Party listing
- [x] Add/Edit party
- [x] Party type categorization (buyer/seller)
- [x] Store-specific party filtering

#### Invoice Management

- [x] Invoice listing
- [x] Add/Edit invoice
- [x] Basic invoice details
- [x] Store-specific invoice filtering
- [x] Recent transactions display

#### Filing Section

- [x] Basic structure
- [x] Navigation setup

### 4. Data Models

- [x] Store model
- [x] Party model
- [x] Invoice model
- [x] User model

### 5. UI Components

- [x] Custom tab bar
- [x] Search bar (UI only)
- [x] Quick action buttons
- [x] Transaction list items
- [x] Analytics cards
- [x] Store selector drawer

## Pending Implementation

### 1. Core Features Enhancement

- [ ] Search functionality implementation
- [ ] Advanced filtering options
- [ ] Batch operations for invoices/parties
- [ ] Data export functionality
- [ ] Report generation
- [ ] PDF invoice generation

### 2. User Experience

- [ ] Loading states optimization
- [ ] Error handling improvements
- [ ] Input validation enhancement
- [ ] User feedback messages
- [ ] Offline support
- [ ] Data caching

### 3. Analytics & Reporting

- [ ] Advanced analytics dashboard
- [ ] Custom date range selection
- [ ] Visual data representation (charts/graphs)
- [ ] Financial reports generation
- [ ] Tax calculation automation
- [ ] Business insights

### 4. Settings & Customization

- [ ] User preferences
- [ ] Theme customization
- [ ] Language support
- [ ] Notification settings
- [ ] Data backup options

### 5. Additional Features

- [ ] Document attachment support
- [ ] Multiple business types support
- [ ] Tax rate management
- [ ] Invoice templates
- [ ] Recurring invoices
- [ ] Payment tracking
- [ ] Contact management
- [ ] Inventory tracking

### 6. Security & Compliance

- [ ] Data encryption
- [ ] Role-based access control
- [ ] Audit logging
- [ ] GST compliance checks
- [ ] Data backup & recovery

### 7. Integration

- [ ] Payment gateway integration
- [ ] Email integration
- [ ] Cloud storage integration
- [ ] Export to accounting software
- [ ] API development for external integrations

## Development Roadmap

### Phase 1: Core Enhancement

1. Implement search functionality
2. Add advanced filtering
3. Improve error handling
4. Enhance data validation
5. Add loading states

### Phase 2: Analytics & Reporting

1. Implement advanced analytics
2. Add visual charts
3. Create report generation
4. Add tax calculations
5. Develop business insights

### Phase 3: User Experience

1. Add offline support
2. Implement data caching
3. Enhance UI/UX
4. Add user preferences
5. Implement notifications

### Phase 4: Advanced Features

1. Add document attachments
2. Implement recurring invoices
3. Add payment tracking
4. Create invoice templates
5. Add inventory management

### Phase 5: Security & Integration

1. Implement role-based access
2. Add audit logging
3. Integrate payment gateways
4. Add cloud storage
5. Develop external APIs

## Notes

- Priority should be given to core feature enhancement
- Focus on stability and performance
- Regular testing and validation required
- User feedback to be incorporated
- Security considerations at each stage
