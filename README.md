# ESL Power - Account Summary Lightning Web Component

An Agentforce-powered Salesforce Lightning Web Component that provides intelligent account summaries with actionable insights, visual dashboards, and seamless email composition capabilities.

## 🎯 What We Built

A comprehensive Account Summary component that transforms complex account data into actionable intelligence. The component aggregates information from Opportunities, Orders, and custom Handoff records, then uses Salesforce's AI Models API to generate contextual summaries and recommended next steps.

### Key Features

- **🤖 AI-Powered Summaries**: Leverages Salesforce Models API to generate intelligent account insights
- **📊 Visual Dashboard**: Beautiful, responsive UI with metrics cards, progress indicators, and data visualization
- **📧 One-Click Email Composition**: Pre-generates email content and opens Salesforce email composer with formatted summary
- **⚡ Real-Time Data Aggregation**: Queries and processes Opportunities, Orders, and Handoff records in real-time
- **🎨 Modern UI/UX**: Built with Lightning Design System, featuring animations, badges, and responsive layouts
- **📈 Key Metrics Tracking**: Pipeline value, open opportunities, active orders, and handoff status
- **✅ Actionable Recommendations**: AI-generated action items with priority levels and timelines
- **📅 Key Dates Timeline**: Visual timeline of critical dates from opportunities and orders

## 🏗️ How It Was Built

### Architecture

The solution follows a clean separation of concerns:

```
┌─────────────────────────────────────────┐
│   Lightning Web Component (LWC)         │
│   - UI Rendering                        │
│   - User Interactions                   │
│   - State Management                    │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│   Apex Controller                       │
│   - Data Aggregation                    │
│   - Agentforce Integration              │
│   - Email Body Generation               │
└──────────────┬──────────────────────────┘
               │
       ┌───────┴────────┐
       ▼                ▼
┌──────────────┐  ┌──────────────┐
│  Salesforce  │  │  Salesforce  │
│   Database   │  │  Models API  │
└──────────────┘  └──────────────┘
```

### Component Structure

```
accountSummary/
├── accountSummary.html    # Template with conditional rendering
├── accountSummary.js      # Component logic & state management
├── accountSummary.css     # Comprehensive styling & animations
└── accountSummary.js-meta.xml

AccountSummaryController.cls
├── getAccountSummary()    # Main entry point
├── queryOpportunities()    # Data retrieval
├── queryOrders()
├── queryHandoffs()
├── processOpportunities()  # Data enrichment
├── processOrders()
├── processHandoffs()
├── buildAIPrompt()         # AI prompt construction
├── getAIInsights()         # AI API integration
└── generateEmailBody()    # Email content generation


## 🚀 Getting Started

### Prerequisites

- Salesforce org with API access
- Lightning Web Component development enabled
- Salesforce Models API access (for AI features)
- Custom Handoff__c object (or modify queries for your objects)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/dylandersen/eslPower.git
   cd eslPower
   ```

2. **Deploy to Salesforce**
   ```bash
   sf project deploy start --target-org your-org-alias
   ```

3. **Add Component to Account Page**
   - Navigate to Account page in Lightning App Builder
   - Add the `accountSummary` component to the page
   - Save and activate

4. **Configure Static Resource**
   - Ensure `Agentforce_RGB_icon` static resource is deployed
   - Or update the import path in `accountSummary.js`

### Configuration

The component automatically uses the Account record ID from the page context. No additional configuration required.

## 📋 Usage

1. **Navigate to an Account record**
2. **Click "Summarize ✨"** button
3. **View the dashboard** with:
   - Key metrics (opportunities, pipeline, orders, handoffs)
   - AI-generated summary
   - Detailed record cards
   - Recommended actions
   - Key dates timeline
4. **Click "Compose"** to open email composer with pre-filled summary

## 🔧 Customization

### Adding Custom Objects

To include additional objects in the summary:

1. Add query method in `AccountSummaryController.cls`:
   ```apex
   private static List<CustomObject__c> queryCustomObjects(String accountId) {
       return [SELECT ... FROM CustomObject__c WHERE Account__c = :accountId];
   }
   ```

2. Process and add to `SummaryResult` class
3. Update LWC template to display custom data

### Modifying AI Prompts

Edit the `buildAIPrompt()` method in `AccountSummaryController.cls` to customize AI behavior and output format.

### Styling

Modify `accountSummary.css` to match your org's branding. The component uses CSS variables for easy theme customization.

## 📊 Data Flow

1. User clicks "Summarize"
2. LWC calls Apex `getAccountSummary()`
3. Apex queries Opportunities, Orders, Handoffs
4. Data is processed and enriched with calculated fields
5. AI prompt is constructed with account context
6. Salesforce Models API generates insights
7. Email body is pre-generated
8. Structured data returned to LWC
9. LWC renders visual dashboard
10. User can compose email with pre-filled content

## 🤝 Contributing

This is a demonstration project. Feel free to fork and adapt for your own use case.

## 📝 License

This project is provided as-is for demonstration purposes.

## 🙏 Acknowledgments

- Built with Salesforce Lightning Web Components
- Powered by Agentforce
- Uses Lightning Design System for UI components

---
