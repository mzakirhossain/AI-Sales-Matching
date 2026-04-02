public with sharing class AIMatchingJob implements Queueable, Database.AllowsCallouts {

    String processId;

    public AIMatchingJob(String processId) {
        this.processId = processId;
    }

    public void execute(QueueableContext context) {

        List<Lead> leads = [
            SELECT Id, Name, Description, Company, Industry
            FROM Lead  where AI_Matched__c = FALSE ORDER BY  ID desc limit 1
        ];

        List<Property_Listing__c> listings = [
            SELECT Id, Name, Capacity__c, Area__c, price_per_desk__c,Amenities__c,Notes__c,Available_from__c
            FROM Property_Listing__c
        ];

        List<User> users = [
            SELECT Id, Name, Speciality__c, IsActive
            FROM User WHERE IsActive = true
        ];

        List<AIMatch_Result__c> resultsToInsert = new List<AIMatch_Result__c>();
        List<Lead> leadsToUpdate = new List<Lead>();
        List<Task> tasksToInsert = new List<Task>();

        for (Lead l : leads) {

            // 🔹 Step 1: Extract structured data AI
            Map<String, Object> extracted =
                AIService.extractLead(l.Description);

            // 🔹 Step 2: AI Filter listings

			List<Property_Listing__c> preFiltered =
				filterListings(listings, extracted);

			// AI refine
			List<String> aiSelectedNames =
				AIService.refineListingsWithAI(extracted, preFiltered);

			// Map back to objects
			List<Property_Listing__c> finalListings = new List<Property_Listing__c>();

			for (Property_Listing__c p : preFiltered) {
				if (aiSelectedNames.contains(p.Name)) {
					finalListings.add(p);
				}
			}

            // 🔹 Step 3: AI reasoning
            Map<String, Object> aiResult =
                AIService.generateMatch(l, finalListings, users);

            Integer confidence = (Integer) aiResult.get('confidence');
            List<Object> listingsRaw = (List<Object>) aiResult.get('top_listings');

            //Build explainable
            List<Map<String, Object>> listingDetails = new List<Map<String, Object>>();

            for (Object o : listingsRaw) {
                Map<String, Object> item = (Map<String, Object>) o;

                listingDetails.add(new Map<String, Object>{
                    'name' => item.get('name'),
                    'score' => item.get('score'),
                    'reasons' => item.get('reasons')
                });
            }            

            // 🔹 Step 4: Prepare DML (NO DML YET)

            AIMatch_Result__c r = new AIMatch_Result__c(
                Process_Id__c = processId,
                Lead__c = l.Id,
                Priority__c = (String) aiResult.get('priority'),
                Insights__c = (String) aiResult.get('insight'),
                Assigned_Agent_Name__c = (String) aiResult.get('assigned_agent'),
                Confidence__c = confidence,
                Listing_log__c = JSON.serialize(listingDetails)
            );

            resultsToInsert.add(r);

            // l.Custom_Notes__c = (String) aiResult.get('insight');
            l.AI_Matched__c = TRUE;
            leadsToUpdate.add(l);

            tasksToInsert.add(new Task(
                Subject = 'Follow up - Suggeted Property Matching - AI',
                WhoId = l.Id,
                OwnerId = users[0].Id
            ));
        }

        // ✅ NOW DML (after callouts)
        insert resultsToInsert;
        update leadsToUpdate;
        insert tasksToInsert;
    }
 	
    private static Map<String, Integer> parseCapacity(String capacityStr) {
        Map<String, Integer> result = new Map<String, Integer>();

        if (String.isBlank(capacityStr)) return result;

        capacityStr = capacityStr.toLowerCase().replace('desks', '').trim();

        // Case 1: non-numeric values like "virtual only"
        if (!Pattern.matches('.*\\d.*', capacityStr)) {
            // no numeric capacity available
            return result;
        }

        try {
            if (capacityStr.contains('-')) {
                List<String> parts = capacityStr.split('-');

                if (parts.size() == 2) {
                    String minStr = parts[0].trim().replaceAll('[^0-9]', '');
                    String maxStr = parts[1].trim().replaceAll('[^0-9]', '');

                    if (!String.isBlank(minStr))
                        result.put('min', Integer.valueOf(minStr));

                    if (!String.isBlank(maxStr))
                        result.put('max', Integer.valueOf(maxStr));
                }

            } else {
                String cleaned = capacityStr.replaceAll('[^0-9]', '');

                if (!String.isBlank(cleaned)) {
                    Integer val = Integer.valueOf(cleaned);
                    result.put('min', val);
                    result.put('max', val);
                }
            }
        } catch (Exception e) {
            // safe fallback: return empty map instead of failing
            System.debug('Capacity parse error: ' + e.getMessage() + ' for value: ' + capacityStr);
        }

        return result;
    }

	public static List<Property_Listing__c> filterListings(
		List<Property_Listing__c> listings,
		Map<String, Object> extracted
	) {
		Integer teamSize = (Integer) extracted.get('team_size');
		String location = (String) extracted.get('location');
		List<Object> preferences = (List<Object>) extracted.get('preferences');

		Map<Id, Integer> scoreMap = new Map<Id, Integer>();

		for (Property_Listing__c p : listings) {

			Integer score = 0;

			// 🔹 1. Capacity Match
			Map<String, Integer> cap = parseCapacity(p.Capacity__c);

			if (cap.containsKey('max') && teamSize != null) {
				if (teamSize <= cap.get('max')) {
					score += 30;

					// Better if within range
					if (teamSize >= cap.get('min')) {
						score += 10;
					}
				} else {
					continue; // ❌ Reject if too small
				}
			}

			// 🔹 2. Location Match
			if (location != null && p.Area__c != null) {
				if (p.Area__c.toLowerCase().contains(location.toLowerCase())) {
					score += 25;
				}
			}

			// 🔹 3. Price Logic (simple heuristic)
			if (p.price_per_desk__c != null) {
				if (p.price_per_desk__c < 700) {
					score += 15; // affordable
				} else {
					score += 5;
				}
			}

			// 🔹 4. Amenities Match
			if (preferences != null && p.Amenities__c != null) {
				for (Object pref : preferences) {
					if (p.Amenities__c.toLowerCase().contains(String.valueOf(pref).toLowerCase())) {
						score += 5;
					}
				}
			}

			// 🔹 5. Notes (premium boost)
			if (p.Notes__c != null && p.Notes__c.toLowerCase().contains('premium')) {
				score += 10;
			}

			// 🔹 6. Availability
			if (p.Available_from__c != null && p.Available_from__c <= Date.today().addDays(30)) {
				score += 10;
			}

			scoreMap.put(p.Id, score);
		}

		// 🔥 Sort by score
		List<Property_Listing__c> sorted = new List<Property_Listing__c>(listings);

		sorted.sort(new ListingComparator(scoreMap));

		// 🔹 Return top 10
		return getTopN(sorted, 10);
	}

	private static List<Property_Listing__c> getTopN(
        List<Property_Listing__c> inputList, Integer n ) 
    {
        List<Property_Listing__c> result = new List<Property_Listing__c>();

        Integer size = Math.min(n, inputList.size());

        for (Integer i = 0; i < size; i++) {
            result.add(inputList[i]);
        }

        return result;
    }
}