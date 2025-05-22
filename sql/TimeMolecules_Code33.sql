USE [TimeSolution]
GO
--[START Code 33 – Create a transform name “arnold.” It aggregates pages having to do with arnold into a single item.]
DECLARE @FM_Transforms NVARCHAR(1000)='{"arnold1":"arnold","arnold2":"arnold","keto1":"dietpage","weightwatcher1":"dietpage","vanproteinbars":"proteinbars","chocproteinbars":"proteinbars"}'
DECLARE @Code NVARCHAR(20)='arnold' --Code or name for the transform.
--@Description is a natural language description of the transform. 
DECLARE @Description NVARCHAR(500)='merge different arnolds and combine keto, weightwatchers to dietpage'
DECLARE @Transformskey VARBINARY(16)
EXEC [dbo].[UpdateTransform] @FM_Transforms, @Code,@Description, @Transformskey OUTPUT
PRINT @TransformsKey
SELECT transformskey, transforms,Code, CreateDate FROM Transforms
--Prints out: 0x903FBEFEFB94CFAD7968D8501583AFAC
--[END Code 33]