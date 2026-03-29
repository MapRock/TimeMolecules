SELECT
	c.CaseID,
	c.NaturalKey,
	c.StartDateTime,
	c.EndDateTime,
	ct.CaseTypeID,
	ct.[Description] AS [CaseTypeDescription],
	lcpp.CaseID AS LinkedCaseID,
	lc.NaturalKey AS LinkedCaseNaturalKey,
	lcpp.PropertyName AS LinkedCasePropertyName,
	lc.StartDateTime AS LinkedCaseStartDate,
	lc.EndDateTime AS LinkedCaseEndDate,
	lct.CaseTypeID AS LinkedCaseTypeID,
	lct.[Description] AS [LinkedCaseTypeDescription],
	CASE WHEN
		c.StartDateTime < lc.EndDateTime AND c.EndDateTime > lc.StartDateTime THEN 1
		ELSE 0
	END CasesOverlap
FROM
	Cases c (NOLOCK)
	JOIN CasePropertiesParsed lcpp (NOLOCK) ON c.NaturalKey=lcpp.PropertyValueAlpha
	JOIN CaseTypes ct (NOLOCK) ON ct.CaseTypeID=c.CaseTypeID
	JOIN Cases lc (NoLOCK) ON lc.CaseID=lcpp.CaseID
	JOIN CaseTypes lct (NOLOCK) ON lct.CaseTypeID=lc.CaseTypeID
WHERE
	c.CaseID != lcpp.CaseID AND
	c.NaturalKey IS NOT NULL
