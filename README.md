# AI-Sales-Matching

📘 AI-Sales-Matching — AI-Powered Sales Operations System
This repository implements a Salesforce-centric AI-powered sales operations solution that mocks the client assessment described in brief. It includes Salesforce metadata (Apex classes, LWC components), mock integration with an LLM API using Named Credentials, and UI logic for processing leads, recommending office listings, and intelligently routing agents.

🧠Introduction & Scope
This project implements an AI-driven matching and sales intelligence engine on top of Salesforce data. It is designed to enable commercial real estate brokers to:
•	Match incoming leads to the most appropriate office listings with reasoning 
•	Generate lead intelligence using historical Salesforce context (Accounts, Opportunities, Users) 
•	Route leads to the right salesperson based on speciality, workload, and existing relationships 
•	Synchronise results back to Salesforce via a mock API layer that mimics Salesforce REST patterns 
This solution can adapt dynamically to new JSON data files and re-evaluate leads without hardcoding logic, fulfilling the deliverables in the Developer Assessment prompt.


🧩 Solution Architecture
<img width="1024" height="559" alt="image" src="https://github.com/user-attachments/assets/1d549d6e-e3a2-4708-80ba-e792ca578332" />

 LWC UI
    ⇣
 Apex Controllers  → JSON input
    ⇣                 (uploaded to Static Resources in Salesforce)
 AI Matching Service → Callout to LLM
    ⇣                   (Named Credentials)
 Salesforce Data (Leads, Accounts, Users, Opps)
    ⇣
 Mock Sync Layer Updates:
   • Lead (assign listings/agents)
   • Task (create follow-up)
   • Opportunity (stage update)
   • Sync History (log)

🔧 Tech Stack
Salesforce-native technologies:
•	Apex — server-side processing logic 
•	LWC (Lightning Web Components) — front-end UI 
•	Named Credentials — secure LLM API integration 
•	Remote Site Settings — allow callout to external APIs 
•	Custom Metadata — configurable API keys & settings 
•	Mock API Behaviour — local CRUD patterns 

•	Custom Object — Property_Listing__c, AIMatch_Result__c 
<img width="488" height="580" alt="image" src="https://github.com/user-attachments/assets/59e4de3a-7983-424c-8158-f7e74b9022d1" />

<img width="471" height="459" alt="image" src="https://github.com/user-attachments/assets/e78fcb17-efd1-493a-9fe6-347d41b8e0ad" />


📂 Repository Structure
AI-Sales-Matching/
├── classes/                      # Apex logic layer
├── customMetadata/               # Custom metadata for LLM configuration
├── lwc/lwcAIMatchinSalesOps/     # UI (Lightning Web Component)
├── namedCredentials/             # Named Credentials for LLM API integration
├── remoteSiteSettings/           # Remote Site setup for callouts
├── package.xml                  # Salesforce deployment manifest
├── LICENSE                      # MIT License
└── README.md                    # Project documentation

<img width="823" height="263" alt="image" src="https://github.com/user-attachments/assets/c96819c3-6f4f-46b6-8291-852074f7f3ba" />


📌 Key Components Explained
🧑💻 Apex Classes (classes/)
Class	Responsibility
AIMatchingController.cls	Entry point for UI-triggered lead processing
AIMatchingJob.cls	Asynchronous LLM processing (batch/queueable)
AIService.cls	Integrates with LLM API and orchestrates matching logic
JSONProcessorController.cls	Parses the input JSON files and returns structured data
ListingComparator.cls	Scores & ranks listings relative to a given lead
AI_DataImportController.cls	Imports JSON data into Salesforce data structures

🧠 Lightning Web Component (lwc/lwcAIMatchinSalesOps/)
The LWC component provides a simple interactive UI:
•	A dashboard listing incoming leads 
•	A button to “Run AI Matching” 
•	Displays matched listings, agent assignment, and reasoning 
•	Shows sync status and AI-generated insights 
The component files:
File	Purpose
lwcAIMatchinSalesOps.html	UI markup
lwcAIMatchinSalesOps.js	Component logic
lwcAIMatchinSalesOps.css	Style definitions
lwcAIMatchinSalesOps.js-meta.xml	Salesforce metadata config

🔑 Named Credentials (namedCredentials/)
OpenAI.namedCredential
This metadata defines the endpoint and authentication configured for your LLM provider (OpenAI, Claude, etc.). Salesforce uses this Named Credential for secure callouts from Apex.

🌐 Remote Site Settings (remoteSiteSettings/)
OpenAI.remoteSite
Required so Salesforce can make external HTTP callouts to the LLM API host.

🛠 Custom Metadata (customMetadata/)
API_Config.OpenAI.md
Used to store configurable values like API keys, LLM model names, or dynamic prompts without hardcoding them in Apex.

📁 How the JSON Data is Used
This project expects two JSON files (similar to the Developer Assessment):
•	salesforce_data.json — contains CRM objects: Leads, Accounts, Opportunities, Users 
•	listings.json — contains office listings data 
These files are processed by the JSONProcessorController.cls which:
1.	Deserializes the JSON into Apex structures 
2.	Provides the data to AIService.cls for LLM classification and recommendation 
3.	Supports dynamic datasets so any future JSON files with similar schema can be processed without code changes 

🤖 LLM Integration Workflow
1.	UI triggers AIMatchingController.processLead(leadId) 
2.	Apex loads relevant JSON data 
3.	Structured payload is built and sent to the LLM via Named Credential 
4.	LLM returns structured JSON (matched listings, reasoning, agent assignment) 
5.	Apex updates Salesforce records accordingly 
6.	Sync history is logged 
This dynamic approach lets the AI adjust to different lead contexts and new datasets.

🛠 Deployment & Setup
1.	Deploy to Salesforce Org 
o	Use Salesforce CLI or Metadata API to push all components 
o	Ensure package.xml includes all classes, LWC, Named Credentials, and Remote Sites 
2.	Configure Named Credentials 
o	Set the endpoint and authentication (e.g. OpenAI API key) 
3.	Enable Remote Site 
o	Allow calls to LLM host (e.g. https://api.openai.com) 
4.	Upload JSON Files 
o	Upload salesforce_data.json and listings.json as Static Resources 
5.	Add LWC to Lightning App 
o	Via Lightning App Builder, add lwcAIMatchinSalesOps to a page 
6.	Run Demo 
o	Open the page 
o	Select a lead and click Run AI Matching 

🧪 Retesting with New JSON Files
To retest with a new dataset:
1. Upload updated salesfor and listing JSON files in to LWC UI, note: Salesforce JSON file name should contain 'Salesforce' and listing JSON file name contcins 'Listing' words.
2.	Re-run the LWC action to upload from first tab
3.	Navigate to AI Matching Tab and click 'Run AI Matching' Action button
4.	The Apex and LLM logic will adapt automatically to new data 
This ensures dynamic behaviour without code changes.
<img width="1244" height="981" alt="SS_Web UI-LWC" src="https://github.com/user-attachments/assets/30481e44-5890-4dab-800e-adc57ecab310" />

<img width="1251" height="1013" alt="SS_Web UI-Lead" src="https://github.com/user-attachments/assets/654bca1c-cce3-4891-8ece-8c81aeedf1ac" />


🚀 Future Improvements
•	Add embeddings + similarity search to speed up matching 
•	Support batch lead processing 
•	Improve UI with filters and insights dashboard 
•	Store historical match outcomes for analytics 

📄 License
This project is licensed under the MIT License.

Author Contact: 
Mohammad Zakir Hossain
m.zakir.bd@gmail.com


