public with sharing class AI_DataImportController {

    // -------------------------------
    // MASTER ENTRY POINT FROM LWC
    // -------------------------------
    @AuraEnabled
    public static Map<String, Object> processUploads(String salesforceJson, String listingsJson) {
        Map<String, Object> result = new Map<String, Object>();
        Boolean hasSalesforce = String.isNotBlank(salesforceJson);
        Boolean hasListings = String.isNotBlank(listingsJson);

        if (!hasSalesforce && !hasListings) {
            throw new AuraHandledException('No JSON files uploaded.');
        }

        try {
            if (hasSalesforce) {
                processSalesforceData(salesforceJson);
            }
            if (hasListings) {
                processListings(listingsJson);
            }

            result.put('status', 'success');
            result.put('message', 'Import completed successfully');
        } catch (Exception e) {
            logError('Combined Import', e.getMessage());
            throw new AuraHandledException('Import Failed: ' + e.getMessage());
        }

        return result;
    }

    // -------------------------------
    // PROCESS LISTINGS.JSON
    // -------------------------------
    public static void processListings(String jsonInput) {
        try {
            Object parsed = JSON.deserializeUntyped(jsonInput);

            List<Object> dataList = new List<Object>();

            // If single object → wrap it
            if (parsed instanceof Map<String, Object>) {
                dataList.add(parsed);
            } else if (parsed instanceof List<Object>) {
                dataList = (List<Object>) parsed;
            }

            List<Property_Listing__c> records = new List<Property_Listing__c>();

            for (Object obj : dataList) {
                Map<String, Object> item = (Map<String, Object>) obj;

                Property_Listing__c rec = new Property_Listing__c(
                    Name = (String) item.get('id'),
                    building__c = (String) item.get('building'),
                    Operator__c = (String) item.get('operator'),
                    Area__c = (String) item.get('area'),
                    Postcode__c = (String) item.get('postcode'),
                    Capacity__c = (String) item.get('capacity'),
                    price_per_desk__c = (item.get('price_per_desk') != null) 
                        ? Decimal.valueOf(String.valueOf(item.get('price_per_desk')))
                        : null,
                    Available_from__c = (item.get('available_from') != null)
                        ? Date.valueOf((String) item.get('available_from'))
                        : null,
                    Amenities__c = item.containsKey('amenities') ? String.join((List<Object>) item.get('amenities'), ', ') : '',
                    Notes__c = (String) item.get('notes')
                );

                records.add(rec);
            }

            insert records;

        } catch (Exception e) {
            logError('Listings Import', e.getMessage());
            throw e;
        }
    }

    // -------------------------------
    // PROCESS SALESFORCE_DATA.JSON
    // -------------------------------
	public static void processSalesforceData(String jsonInput) {
		try {
			Map<String, Object> dataMap = (Map<String, Object>) JSON.deserializeUntyped(jsonInput);

			insertLeads((List<Object>) dataMap.get('leads'));

			// 🔥 NEW — accounts inserted first, mapping returned
			Map<String, Id> accMap = insertAccounts((List<Object>) dataMap.get('accounts'));

			// 🔥 NEW — opportunities use the new Account IDs
			insertOpportunities(
				(List<Object>) dataMap.get('opportunities'),
				accMap
			);

			// insertUsers((List<Object>) dataMap.get('users'));

		} catch (Exception e) {
			logError('Salesforce Data Import', e.getMessage());
			throw e;
		}
	}

    // -------------------------------
    // LEAD IMPORT
    // -------------------------------
    private static void insertLeads(List<Object> leads) {
        if (leads == null) return;
        List<Lead> records = new List<Lead>();

        for (Object obj : leads) {
            Map<String, Object> item = (Map<String, Object>) obj;

            Lead l = new Lead(
                FirstName = (String) item.get('FirstName'),
                LastName = (String) item.get('LastName'),
                Company = (String) item.get('Company'),
                Email = (String) item.get('Email'),
                Phone = (String) item.get('Phone'),
                LeadSource = (String) item.get('LeadSource'),
                Status = (String) item.get('Status'),
                Industry = (String) item.get('Industry'),
                Description = (String) item.get('Description'),
                Custom_Notes__c = (String) item.get('Custom_Notes__c'),
				external_id__c = (String) item.get('Id')
            );

            records.add(l);
        }

        upsert records external_id__c;
    }

    // -------------------------------
    // ACCOUNT IMPORT
    // -------------------------------
   // Return map of Old JSON Id → Newly Inserted SFDC Id
	private static Map<String, Id> insertAccounts(List<Object> accounts) {
		Map<String, Id> accMap = new Map<String, Id>(); 
		if (accounts == null) return accMap;

		List<Account> records = new List<Account>();

		// Temporarily hold oldId → Account skeleton before insert
		Map<String, Account> tempMap = new Map<String, Account>();

		for (Object obj : accounts) {
			Map<String, Object> item = (Map<String, Object>) obj;

			String oldId = (String) item.get('Id'); // JSON Id

			Account a = new Account(
				Name = (String) item.get('Name'),
				Type = (String) item.get('Type'),
				Industry = (String) item.get('Industry'),
				BillingCity = (String) item.get('BillingCity'),
				Phone = (String) item.get('Phone'),
				Description = (String) item.get('Description'),
				// OwnerId = (String) item.get('OwnerId'),
				Owner_Name__c = (String) item.get('Owner_Name__c'),
				external_id__c = (String) item.get('Id')
			);

			records.add(a);
			tempMap.put(oldId, a);
		}

        upsert records external_id__c;

		// After insert: build mapping oldId → new Salesforce Id
		for (String oldId : tempMap.keySet()) {
			accMap.put(oldId, tempMap.get(oldId).Id);
		}

		return accMap;
	}

    // -------------------------------
    // OPPORTUNITY IMPORT
    // -------------------------------
    private static void insertOpportunities(
		List<Object> opportunities,
		Map<String, Id> accountIdMap
	) {
		if (opportunities == null) return;

		List<Opportunity> records = new List<Opportunity>();

		for (Object obj : opportunities) {
			Map<String, Object> item = (Map<String, Object>) obj;

			String oldAccId = (String) item.get('AccountId');
			Id newAccId = accountIdMap.get(oldAccId);

			Opportunity o = new Opportunity(
				Name = (String) item.get('Name'),
				StageName = (String) item.get('StageName'),
				AccountId = newAccId,   // ← FIXED: using MAP
				Amount = item.get('Amount') != null 
					? Decimal.valueOf(String.valueOf(item.get('Amount'))) 
					: null,
				CloseDate = item.get('CloseDate') != null 
					? Date.valueOf((String) item.get('CloseDate')) 
					: null,
				Description = (String) item.get('Description'),
				// OwnerId = (String) item.get('OwnerId'),
				Owner_Name__c = (String) item.get('Owner_Name__c'),
				Loss_Reason__c = (String) item.get('Loss_Reason__c'),
				external_id__c = (String) item.get('Id')
			);

			records.add(o);
		}

        upsert records external_id__c;
	}

    // -------------------------------
    // USER IMPORT
    // -------------------------------
    // private static void insertUsers(List<Object> users) {
    //     if (users == null) return;

    //     List<User> records = new List<User>();

    //     for (Object obj : users) {
    //         Map<String, Object> item = (Map<String, Object>) obj;

    //         User u = new User(
    //             IsActive = (Boolean) item.get('IsActive'),
    //             UserRoleId = null,
    //             Speciality__c = (String) item.get('Speciality__c')
    //         );

    //         records.add(u);
    //     }

    //     update records name;
    // }

    // -------------------------------
    // ERROR LOGGER
    // -------------------------------
    private static void logError(String fileName, String message) {
        AI_Import_Log__c log = new AI_Import_Log__c(
            File_Name__c = fileName,
            Status__c = 'Failed',
            Message__c = message
        );
        insert log;
    }
}