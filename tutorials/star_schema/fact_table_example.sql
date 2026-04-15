/*
Sample of a SQL that generates a fact table from case-level and event-level properties.

Should be saved as a "FACT" table, as in a dimensional model, using the FACT schema. ex. FACT.[Fuel_Weight]
*/
SELECT
	e.[EventID],
	e.EventDate,
	e.CaseID,
	CASE WHEN l.PropertyValueNumeric IS NULL THEN -1 ELSE l.PropertyValueNumeric END AS [LocationID],
	f.PropertyValueNumeric AS [Fuel],
	w.PropertyValueNumeric [Weight]
FROM
	[EventsFact] e (NOLOCK)
	LEFT JOIN [dbo].[EventPropertiesParsed] f (NOLOCK) ON f.EventID=e.EventID AND f.PropertyName='Fuel'
	LEFT JOIN [dbo].[EventPropertiesParsed] w (NOLOCK) ON w.EventID=e.EventID AND w.PropertyName='Weight'
	LEFT JOIN [dbo].[CasePropertiesParsed] l (NOLOCK) ON l.CaseID=e.CaseID AND l.PropertyName='LocationID'
WHERE
	(
		f.PropertyValueNumeric IS NOT NULL OR
		w.PropertyValueNumeric IS NOT NULL
	)
