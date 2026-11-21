// BidPilot demo data. Safe to re-run: clears previous demo records first.
delete [SELECT Id FROM Bid__c];
delete [SELECT Id FROM Resource__c];
delete [SELECT Id FROM Past_Project__c];

insert new List<Resource__c>{
    new Resource__c(Name = 'Arun Kumar',  Role__c = 'Senior Salesforce Developer', Skills__c = 'Apex, LWC, Flow, Service Cloud', Hourly_Rate__c = 1800, Current_Allocation__c = 30, Experience_Years__c = 5, Active__c = true),
    new Resource__c(Name = 'Divya R',     Role__c = 'Experience Cloud Specialist', Skills__c = 'Experience Cloud, LWC, CMS',     Hourly_Rate__c = 2000, Current_Allocation__c = 50, Experience_Years__c = 4, Active__c = true),
    new Resource__c(Name = 'Karthik S',   Role__c = 'Project Manager',             Skills__c = 'Agile, Delivery, Scrum',         Hourly_Rate__c = 2500, Current_Allocation__c = 40, Experience_Years__c = 9, Active__c = true),
    new Resource__c(Name = 'Priya M',     Role__c = 'Integration Engineer',        Skills__c = 'Integration, MuleSoft, REST API, SAP', Hourly_Rate__c = 2200, Current_Allocation__c = 80, Experience_Years__c = 6, Active__c = true),
    new Resource__c(Name = 'Vignesh P',   Role__c = 'Mobile Developer',            Skills__c = 'React Native, Mobile',           Hourly_Rate__c = 1700, Current_Allocation__c = 20, Experience_Years__c = 3, Active__c = true),
    new Resource__c(Name = 'Meena K',     Role__c = 'QA Engineer',                 Skills__c = 'Testing, Selenium, Provar',      Hourly_Rate__c = 1200, Current_Allocation__c = 30, Experience_Years__c = 4, Active__c = true),
    new Resource__c(Name = 'Sanjay T',    Role__c = 'Data Engineer',               Skills__c = 'Data Migration, ETL, Data Loader', Hourly_Rate__c = 1600, Current_Allocation__c = 60, Experience_Years__c = 5, Active__c = true),
    new Resource__c(Name = 'Lakshmi V',   Role__c = 'Salesforce Admin & Analyst',  Skills__c = 'Reports, Dashboards, Configuration, Service Cloud', Hourly_Rate__c = 1300, Current_Allocation__c = 10, Experience_Years__c = 3, Active__c = true)
};

insert new List<Past_Project__c>{
    new Past_Project__c(Name = 'Dealer Portal',          Client_Name__c = 'Sri Ram Motors',     Domain__c = 'Automotive', Skills__c = 'Experience Cloud, Apex, LWC',       Module_Count__c = 5, Planned_Effort_Hours__c = 900,  Actual_Effort_Hours__c = 1080, Completed_On__c = Date.today().addMonths(-4)),
    new Past_Project__c(Name = 'Service Cloud Rollout',  Client_Name__c = 'Kaveri Appliances',  Domain__c = 'Consumer',   Skills__c = 'Service Cloud, Flow, Reports',      Module_Count__c = 4, Planned_Effort_Hours__c = 600,  Actual_Effort_Hours__c = 660,  Completed_On__c = Date.today().addMonths(-7)),
    new Past_Project__c(Name = 'SAP Order Sync',         Client_Name__c = 'Coastal Foods',      Domain__c = 'FMCG',       Skills__c = 'Integration, MuleSoft, SAP',        Module_Count__c = 3, Planned_Effort_Hours__c = 500,  Actual_Effort_Hours__c = 690,  Completed_On__c = Date.today().addMonths(-2)),
    new Past_Project__c(Name = 'Legacy CRM Migration',   Client_Name__c = 'Vel Finance',        Domain__c = 'BFSI',       Skills__c = 'Data Migration, ETL',               Module_Count__c = 2, Planned_Effort_Hours__c = 300,  Actual_Effort_Hours__c = 330,  Completed_On__c = Date.today().addMonths(-9)),
    new Past_Project__c(Name = 'Field Sales App',        Client_Name__c = 'Agro Fresh',         Domain__c = 'Agri',       Skills__c = 'React Native, Mobile, Apex',        Module_Count__c = 4, Planned_Effort_Hours__c = 700,  Actual_Effort_Hours__c = 770,  Completed_On__c = Date.today().addMonths(-5)),
    new Past_Project__c(Name = 'Claims Self-Service',    Client_Name__c = 'Trust Insurance',    Domain__c = 'Insurance',  Skills__c = 'Experience Cloud, Service Cloud, WhatsApp', Module_Count__c = 6, Planned_Effort_Hours__c = 1100, Actual_Effort_Hours__c = 1320, Completed_On__c = Date.today().addMonths(-3))
};

Bid__c demo = new Bid__c(
    Client_Name__c = 'Nila Logistics Pvt Ltd',
    Project_Title__c = 'Nila Connect - Customer Service Portal',
    Requested_Timeline_Weeks__c = 8,
    Status__c = 'Draft',
    SOW_Content__c = 'STATEMENT OF WORK\n'
        + 'Client: Nila Logistics Pvt Ltd, Chennai\n'
        + 'Project: Nila Connect - Customer Service and Shipment Portal\n'
        + 'Date: 12 November 2026\n'
        + '\n'
        + '1. BACKGROUND\n'
        + 'Nila Logistics moves 4,000+ shipments a day across South India for 1,200 B2B customers. Today customers call or email the support desk to track shipments, raise damage claims and download invoices. The support team of 25 agents spends most of its time on these repetitive requests. Nila wants a self-service experience on Salesforce.\n'
        + '\n'
        + '2. SCOPE OF WORK\n'
        + '2.1 Customer Self-Service Portal\n'
        + '- Branded portal on Salesforce Experience Cloud for B2B customers with login, profile and multi-user accounts.\n'
        + '- Customers can raise and track service requests and damage claims with photo upload.\n'
        + '\n'
        + '2.2 Live Shipment Tracking\n'
        + '- Real-time shipment status and map view inside the portal.\n'
        + '- Shipment events come from Nila\'s existing TMS (Transport Management System) through REST APIs.\n'
        + '\n'
        + '2.3 SAP Invoice Integration\n'
        + '- Invoices and payment status must be pulled from SAP S/4HANA and shown in the portal.\n'
        + '- Customers can download invoice PDFs.\n'
        + '- SAP API documentation will be shared after the project kick-off.\n'
        + '\n'
        + '2.4 Service Cloud for Support Agents\n'
        + '- Case management with SLA timers, auto-assignment by region and escalation rules.\n'
        + '- Agent console showing customer, shipment and invoice details in one view.\n'
        + '\n'
        + '2.5 WhatsApp Notifications\n'
        + '- Automatic WhatsApp updates to customers on shipment pickup, delay and delivery.\n'
        + '- WhatsApp Business provider is yet to be finalised by Nila.\n'
        + '\n'
        + '2.6 Data Migration\n'
        + '- Migrate 1,200 customer accounts, 8,000 contacts and 2 years of open claims from the legacy MySQL helpdesk.\n'
        + '\n'
        + '2.7 Management Dashboards\n'
        + '- Dashboards for claims, SLA compliance and customer satisfaction. Exact list of reports to be decided during the project.\n'
        + '\n'
        + '3. TIMELINE\n'
        + 'Nila requires go-live within 8 weeks from kick-off to align with the festive season peak.\n'
        + '\n'
        + '4. COMMERCIAL TERMS\n'
        + '- Fixed price engagement.\n'
        + '- A penalty of 2% of contract value per week applies for any delay in go-live.\n'
        + '\n'
        + '5. ASSUMPTIONS\n'
        + '- Nila will provide a UAT environment for TMS and SAP.\n'
        + '- Nila\'s IT team has limited availability (one part-time contact).\n'
);
insert demo;
System.debug('BidPilot demo ready: ' + [SELECT Name FROM Bid__c WHERE Id = :demo.Id].Name);
