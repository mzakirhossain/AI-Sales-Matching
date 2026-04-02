public class ListingComparator implements Comparator<Property_Listing__c> {

    Map<Id, Integer> scoreMap;

    public ListingComparator(Map<Id, Integer> scoreMap) {
        this.scoreMap = scoreMap;
    }

    public Integer compare(Property_Listing__c a, Property_Listing__c b) {
        Integer scoreA = scoreMap.containsKey(a.Id) ? scoreMap.get(a.Id) : 0;
        Integer scoreB = scoreMap.containsKey(b.Id) ? scoreMap.get(b.Id) : 0;

        return scoreB - scoreA; // DESC
    }


	public static List<Property_Listing__c> getTopN(
        List<Property_Listing__c> inputList,
        Integer n
    ) {
        List<Property_Listing__c> result = new List<Property_Listing__c>();

        Integer size = Math.min(n, inputList.size());

        for (Integer i = 0; i < size; i++) {
            result.add(inputList[i]);
        }

        return result;
    }
}