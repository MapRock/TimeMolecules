USE [TimeSolution]
GO
	
DROP TABLE IF EXISTS #tmp
/*
This code will help us figure out which case types might be related to each other.
For example, a restaurant might consist of a dining room process and a separate kitchen process.
They meet up when the waiter submits the order and when the kitchen finishes the order and the waiter serves the meal.
The two processes could be found to link it the natural key of the dining room process is passed as ParentNaturalKey
to the kitchen process.

#tmp will match a case natural key to other cases of different case types that have properties with the same value.

This code for #tmp will be posted on:

https://github.com/MapRock/TimeMolecules/blob/main/docs/link_case_types_by_event_properties/event_property_matches.sql
	
*** Compare find_related_case_types.sql and the stored procedure, sp_CompareEventProximities ***

They are related, but different. find_related_case_types.sql is a case-link discovery script that rolls up to case-type relationships.
sp_CompareEventProximities is a parameterized comparison procedure that compares two chosen populations at the event-property level and returns richer descriptive output.

This code is asking, “which case types seem linkable at all?” The stored procedure is asking, “for these two selected populations, what event-property evidence do they have in common?”


*/
SELECT
	c.CaseID,
	nksc.SourceColumnID AS [NaturalKey_SourceColumnID],
	nksc.ColumnName AS NaturalKeyColName,
	nksc.[Description] AS NaturalKeyColDesc,
	c.NaturalKey,
	c.StartDateTime,
	c.EndDateTime,
	ct.CaseTypeID,
	ct.[Description] AS [CaseTypeDescription],
	lcpp.CaseID AS LinkedCaseID,
	lc.NaturalKey AS LinkedCaseNaturalKey,
	lcpp.PropertyName AS LinkedCasePropertyName,
	lsc.SourceColumnID AS [LinkedSourceColumnID],
	lsc.[Description] AS LinkedPropCaseSourceColumnDesc,
	lc.StartDateTime AS LinkedCaseStartDate,
	lc.EndDateTime AS LinkedCaseEndDate,
	lct.CaseTypeID AS LinkedCaseTypeID,
	lct.[Description] AS [LinkedCaseTypeDescription],
	CASE WHEN
		c.StartDateTime < lc.EndDateTime AND c.EndDateTime > lc.StartDateTime THEN 1
		ELSE 0
	END CasesOverlap
INTO #tmp
FROM
	Cases c (NOLOCK)
	JOIN CasePropertiesParsed lcpp (NOLOCK) ON c.NaturalKey=lcpp.PropertyValueAlpha
	JOIN CaseTypes ct (NOLOCK) ON ct.CaseTypeID=c.CaseTypeID
	JOIN Cases lc (NoLOCK) ON lc.CaseID=lcpp.CaseID
	JOIN CaseTypes lct (NOLOCK) ON lct.CaseTypeID=lc.CaseTypeID
	LEFT JOIN SourceColumns lsc oN lsc.SourceID=lc.SourceID AND lsc.ColumnName=lcpp.PropertyName
	LEFT JOIN SourceColumns nksc ON nksc.SourceColumnID=c.NaturalKey_SourceColumnID
WHERE
	c.CaseID != lcpp.CaseID AND
	c.NaturalKey IS NOT NULL AND
	c.CaseTypeID != lc.CaseTypeID 
	
	AND
	(
		EXISTS (SELECT 1 FROM [dbo].[SimilarSourceColumnPairs] scp 
			WHERE scp.[SourceColumnID1]=nksc.SourceColumnID AND scp.SourceColumnID2=lsc.SourceColumnID) OR
		EXISTS (SELECT 1 FROM [dbo].[SimilarSourceColumnPairs] scp 
			WHERE scp.[SourceColumnID2]=nksc.SourceColumnID AND scp.SourceColumnID1=lsc.SourceColumnID) 
	)
	

SELECT * FROM #tmp order by caseid

/*
This will create the final result, showing which case types have some event property in common,
therefore, they might be related.

This code for the final output will be on:

https://github.com/MapRock/TimeMolecules/blob/main/docs/link_case_types_by_event_properties/event_property_matches_final.sql
*/
;
;WITH ttl AS
(
	SELECT
		c.CaseTypeID,
		COUNT(*) AS TotalCaseCount
	FROM
		dbo.Cases c
	WHERE
		c.CaseTypeID IN 
		(
			SELECT DISTINCT 
				t.CaseTypeID 
			FROM 
				#tmp t
		)
	GROUP BY
		c.CaseTypeID
),
lnk AS
(
	SELECT
		t.CaseTypeID,
		MAX(t.CaseTypeDescription) AS CaseTypeDescription,
		t.LinkedCaseTypeID,
		MAX(t.LinkedCaseTypeDescription) AS LinkedCaseTypeDescription,
		COUNT(DISTINCT LinkedCaseID) AS LinkedCount,
		SUM(CASE WHEN t.CasesOverlap = 1 THEN 1 ELSE 0 END) AS OverlapCount,
		SUM(CASE WHEN t.CasesOverlap = 0 THEN 1 ELSE 0 END) AS NonOverlapCount
	FROM
		#tmp t
	GROUP BY
		t.CaseTypeID,
		t.LinkedCaseTypeID
)
SELECT
	l.CaseTypeID,
	l.CaseTypeDescription,
	ttl.TotalCaseCount,
	l.LinkedCaseTypeID,
	l.LinkedCaseTypeDescription,
	l.LinkedCount,
	ROUND(CAST(l.LinkedCount AS FLOAT) / NULLIF(ttl.TotalCaseCount,0),3)*100 AS LinkedPctOfCaseType,
	l.OverlapCount,
	l.NonOverlapCount,
	CAST(l.OverlapCount AS FLOAT) / NULLIF(l.LinkedCount,0) AS OverlapPctWithinLinkType
FROM
	lnk l
	JOIN ttl
		ON ttl.CaseTypeID = l.CaseTypeID
ORDER BY
	l.CaseTypeID,
	l.LinkedCount DESC,
	l.LinkedCaseTypeID;
