USE [TimeSolution]
GO
/****** Object:  Table [dbo].[Access]    Script Date: 4/8/2026 9:44:54 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Access](
	[AccessID] [int] NOT NULL,
	[Description] [nvarchar](100) NOT NULL,
 CONSTRAINT [PK_Access] PRIMARY KEY CLUSTERED 
(
	[AccessID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[AggregationTypes]    Script Date: 4/8/2026 9:44:54 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[AggregationTypes](
	[AggregationTypeID] [int] NOT NULL,
	[Description] [nvarchar](100) NOT NULL,
	[IsNative] [bit] NOT NULL,
	[Metadata] [nvarchar](max) NULL,
 CONSTRAINT [PK_Aggregations] PRIMARY KEY CLUSTERED 
(
	[AggregationTypeID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[BayesianProbabilities]    Script Date: 4/8/2026 9:44:54 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[BayesianProbabilities](
	[ModelID] [int] NOT NULL,
	[GroupType] [nvarchar](20) NOT NULL,
	[EventSetAKey] [varbinary](16) NOT NULL,
	[EventSetBKey] [varbinary](16) NOT NULL,
	[ACount] [int] NULL,
	[BCount] [int] NULL,
	[A_Int_BCount] [int] NULL,
	[PB|A] [float] NULL,
	[PA|B] [float] NOT NULL,
	[TotalCases] [int] NULL,
	[PA] [float] NULL,
	[PB] [float] NULL,
	[CreateDate] [datetime] NOT NULL,
	[AnomalyCategoryIDA] [int] NULL,
	[AnomalyCategoryIDB] [int] NULL,
	[LastUpdate] [datetime] NULL
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[CaseProperties]    Script Date: 4/8/2026 9:44:54 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CaseProperties](
	[CaseID] [int] NOT NULL,
	[Properties] [nvarchar](max) NULL,
	[TargetProperties] [nvarchar](max) NULL,
	[CreateDate] [datetime] NULL,
 CONSTRAINT [PK_CaseProperties_1] PRIMARY KEY CLUSTERED 
(
	[CaseID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[CasePropertiesMDM]    Script Date: 4/8/2026 9:44:54 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CasePropertiesMDM](
	[SourceColumnID] [int] NOT NULL,
	[PropertyName] [nvarchar](20) NOT NULL,
	[MDMSourceColumnID] [int] NOT NULL,
	[PropertyValueNumeric] [float] NULL,
	[PropertyValueAlpha] [nvarchar](1000) NULL,
	[MDMName] [nvarchar](20) NOT NULL,
	[MDMValueNumeric] [float] NULL,
	[MDMValueAlpha] [nvarchar](1000) NULL,
	[CreateDate] [datetime] NOT NULL,
	[LastUpdate] [datetime] NOT NULL,
	[MDMVersionID] [int] NOT NULL,
	[SimilarityScore] [float] NOT NULL,
	[MDMComparisonTypeID] [int] NULL,
 CONSTRAINT [PK_CasePropertiesMDM] PRIMARY KEY CLUSTERED 
(
	[SourceColumnID] ASC,
	[PropertyName] ASC,
	[MDMSourceColumnID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[CasePropertiesParsed]    Script Date: 4/8/2026 9:44:54 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CasePropertiesParsed](
	[CaseID] [int] NOT NULL,
	[PropertyName] [nvarchar](50) NOT NULL,
	[PropertyValueNumeric] [float] NULL,
	[PropertyValueAlpha] [nvarchar](1000) NULL,
	[SourceColumnID] [int] NULL,
	[AddedProperty] [bit] NULL,
	[CreateDate] [datetime] NULL,
	[LastUpdate] [datetime] NULL,
	[SortValue] [int] NULL,
	[StartDateTime] [datetime] NULL,
	[EndDateTime] [datetime] NULL,
 CONSTRAINT [PK_CaseProperties] PRIMARY KEY CLUSTERED 
(
	[PropertyName] ASC,
	[CaseID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Cases]    Script Date: 4/8/2026 9:44:54 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Cases](
	[CaseID] [bigint] NOT NULL,
	[CaseTypeID] [int] NOT NULL,
	[StartDateTime] [datetime] NULL,
	[SourceID] [int] NULL,
	[EndDateTime] [datetime] NULL,
	[EventCount] [int] NULL,
	[AccessBitmap] [bigint] NULL,
	[CreateDate] [datetime] NULL,
	[BatchID] [bigint] NULL,
	[NaturalKey] [nvarchar](200) NULL,
	[Event_SourceColumnID] [int] NULL,
	[Date_SourceColumnID] [int] NULL,
	[NaturalKey_SourceColumnID] [int] NULL,
 CONSTRAINT [PK_Cases] PRIMARY KEY CLUSTERED 
(
	[CaseID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[CaseTypes]    Script Date: 4/8/2026 9:44:54 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CaseTypes](
	[CaseTypeID] [int] IDENTITY(1,1) NOT NULL,
	[Description] [nvarchar](500) NOT NULL,
	[ParentCaseTypeID] [int] NULL,
	[Name] [nvarchar](50) NOT NULL,
	[IRI] [nvarchar](500) NULL,
	[AccessBitmap] [bigint] NULL,
 CONSTRAINT [PK_CaseTypes] PRIMARY KEY CLUSTERED 
(
	[CaseTypeID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[DimAnomalyCategories]    Script Date: 4/8/2026 9:44:54 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[DimAnomalyCategories](
	[AmomalyCategoryID] [int] NOT NULL,
	[Code] [nvarchar](50) NULL,
	[Description] [nvarchar](500) NULL,
	[IRI] [nvarchar](500) NULL,
 CONSTRAINT [PK_DimAnomalyCategories] PRIMARY KEY CLUSTERED 
(
	[AmomalyCategoryID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[DimDate]    Script Date: 4/8/2026 9:44:54 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[DimDate](
	[DateKey] [int] NOT NULL,
	[FullDate] [date] NOT NULL,
	[Year] [int] NOT NULL,
	[Quarter] [int] NOT NULL,
	[Month] [int] NOT NULL,
	[Day] [int] NOT NULL,
	[Dow] [int] NULL,
PRIMARY KEY CLUSTERED 
(
	[DateKey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[DimEvents]    Script Date: 4/8/2026 9:44:54 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[DimEvents](
	[Event] [nvarchar](50) NOT NULL,
	[Description] [nvarchar](500) NULL,
	[Properties] [nvarchar](max) NULL,
	[CreateDate] [datetime] NOT NULL,
	[LastUpdated] [datetime] NOT NULL,
	[IRI] [nvarchar](500) NULL,
	[SourceID] [int] NOT NULL,
	[IsState] [bit] NOT NULL,
 CONSTRAINT [PK_DimEvents] PRIMARY KEY CLUSTERED 
(
	[Event] ASC,
	[SourceID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[DimObservers]    Script Date: 4/8/2026 9:44:54 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[DimObservers](
	[ObserverID] [bigint] IDENTITY(1,1) NOT NULL,
	[Code] [nvarchar](50) NOT NULL,
	[Description] [nvarchar](500) NULL,
	[IRI] [nvarchar](500) NULL,
	[SourceID] [int] NULL,
	[NaturalKey] [nvarchar](100) NULL,
	[Parent_ObserverID] [bigint] NULL,
 CONSTRAINT [PK_DimObservers] PRIMARY KEY CLUSTERED 
(
	[ObserverID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[DimTime]    Script Date: 4/8/2026 9:44:54 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[DimTime](
	[TimeKey] [int] NOT NULL,
	[Hour] [int] NOT NULL,
	[Minute] [int] NOT NULL,
	[Second] [int] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[TimeKey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[EventPairAnomalies]    Script Date: 4/8/2026 9:44:54 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[EventPairAnomalies](
	[ModelID] [int] NOT NULL,
	[CaseID] [int] NOT NULL,
	[EventIDA] [int] NOT NULL,
	[EventIDB] [int] NOT NULL,
	[AnomalyCode] [nvarchar](50) NOT NULL,
	[EventA] [nvarchar](20) NOT NULL,
	[EventB] [nvarchar](20) NULL,
	[metric_zscore] [float] NULL,
	[metric_value] [float] NULL,
	[transistion_prob] [float] NULL,
	[EventAIsEntry] [bit] NOT NULL,
	[EventBIsExit] [bit] NOT NULL,
	[CreateDate] [datetime] NULL,
	[MetricID] [int] NULL
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[EventProperties]    Script Date: 4/8/2026 9:44:54 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[EventProperties](
	[EventID] [int] NOT NULL,
	[ActualProperties] [nvarchar](max) NULL,
	[ExpectedProperties] [nvarchar](max) NULL,
	[AggregationProperties] [nvarchar](max) NULL,
	[LastUpdated] [datetime] NULL,
	[CreateDate] [datetime] NULL,
	[IntendedProperties] [nvarchar](max) NULL,
	[TriggerFunction] [nvarchar](max) NULL,
 CONSTRAINT [PK_EventProperties] PRIMARY KEY CLUSTERED 
(
	[EventID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[EventPropertiesMDM]    Script Date: 4/8/2026 9:44:54 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[EventPropertiesMDM](
	[SourceColumnID] [int] NOT NULL,
	[PropertyName] [nvarchar](20) NOT NULL,
	[MDMSourceColumnID] [int] NOT NULL,
	[PropertyValueNumeric] [float] NULL,
	[PropertyValueAlpha] [nvarchar](1000) NULL,
	[MDMName] [nvarchar](20) NOT NULL,
	[MDMValueNumeric] [float] NULL,
	[MDMValueAlpha] [nvarchar](1000) NULL,
	[CreateDate] [datetime] NOT NULL,
	[LastUpdate] [datetime] NOT NULL,
	[SimilarityScore] [float] NOT NULL,
	[MDMComparisonTypeID] [int] NOT NULL,
 CONSTRAINT [PK_EventPropertiesMDM] PRIMARY KEY CLUSTERED 
(
	[SourceColumnID] ASC,
	[PropertyName] ASC,
	[MDMSourceColumnID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[EventPropertiesParsed]    Script Date: 4/8/2026 9:44:54 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[EventPropertiesParsed](
	[EventID] [int] NOT NULL,
	[PropertyName] [nvarchar](50) NOT NULL,
	[PropertySource] [tinyint] NOT NULL,
	[PropertyValueNumeric] [float] NULL,
	[PropertyValueAlpha] [nvarchar](1000) NULL,
	[IsJSON] [bit] NULL,
	[SourceColumnID] [int] NULL,
	[CreateDate] [datetime] NULL,
	[LastUpdate] [datetime] NULL,
	[EventPropertyCountAllocation] [real] NULL,
	[EventDate] [datetime] NULL,
	[Event] [nvarchar](20) NULL,
	[CaseID] [bigint] NULL,
 CONSTRAINT [PK_EventPropertiesParsed] PRIMARY KEY CLUSTERED 
(
	[EventID] ASC,
	[PropertyName] ASC,
	[PropertySource] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[EventSets]    Script Date: 4/8/2026 9:44:54 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[EventSets](
	[EventSetKey] [varbinary](16) NOT NULL,
	[EventSet] [nvarchar](4000) NOT NULL,
	[EventSetCode] [nvarchar](20) NULL,
	[IsSequence] [bit] NOT NULL,
	[CreateDate] [datetime] NOT NULL,
	[CreatedByUserID] [int] NULL,
	[Description] [nvarchar](500) NULL,
	[DescriptionAuthorUserID] [int] NULL,
	[IRI] [nvarchar](500) NULL,
	[LastUpdate] [datetime] NULL,
	[IsCaseProperty] [bit] NOT NULL,
	[Length] [int] NULL,
 CONSTRAINT [PK_IncludedEvents] PRIMARY KEY CLUSTERED 
(
	[EventSetKey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[EventsFact]    Script Date: 4/8/2026 9:44:54 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[EventsFact](
	[CaseID] [bigint] NOT NULL,
	[Event] [nvarchar](50) NOT NULL,
	[EventDate] [datetime2](7) NOT NULL,
	[EventID] [bigint] IDENTITY(1,1) NOT NULL,
	[SourceID] [int] NULL,
	[AggregationTypeID] [int] NULL,
	[CreateDate] [datetime] NOT NULL,
	[CaseOrdinal] [int] NULL,
	[ParentCaseID] [bigint] NULL,
	[BatchID] [bigint] NULL,
	[AccessBitmap] [bigint] NULL
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[MDMComparisonTypes]    Script Date: 4/8/2026 9:44:54 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[MDMComparisonTypes](
	[MDMComparisonTypeID] [int] NOT NULL,
	[Description] [nvarchar](200) NULL,
 CONSTRAINT [PK_MDMComparisonTypes] PRIMARY KEY CLUSTERED 
(
	[MDMComparisonTypeID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Metrics]    Script Date: 4/8/2026 9:44:54 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Metrics](
	[MetricID] [int] IDENTITY(1,1) NOT NULL,
	[Metric] [nvarchar](50) NOT NULL,
	[Method] [int] NULL,
	[UoM] [nvarchar](20) NULL,
	[Description] [nvarchar](500) NULL,
	[IRI] [nvarchar](500) NULL,
 CONSTRAINT [PK_Metrics] PRIMARY KEY CLUSTERED 
(
	[MetricID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Model_Stationary_Distribution]    Script Date: 4/8/2026 9:44:54 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Model_Stationary_Distribution](
	[ModelID] [int] NOT NULL,
	[Event] [nvarchar](20) NOT NULL,
	[Probability] [float] NOT NULL,
	[CreateDate] [datetime] NULL,
 CONSTRAINT [PK_Model_Stationary_Distribution] PRIMARY KEY CLUSTERED 
(
	[ModelID] ASC,
	[Event] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[ModelEvents]    Script Date: 4/8/2026 9:44:54 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ModelEvents](
	[ModelID] [int] NOT NULL,
	[EventA] [nvarchar](20) NOT NULL,
	[EventB] [nvarchar](20) NOT NULL,
	[Max] [float] NULL,
	[Avg] [float] NULL,
	[Min] [float] NULL,
	[StDev] [float] NULL,
	[CoefVar] [float] NULL,
	[Rows] [int] NULL,
	[Prob] [float] NULL,
	[IsEntry] [int] NOT NULL,
	[Sum] [float] NULL,
	[IsExit] [int] NOT NULL,
	[Event2A] [nvarchar](20) NOT NULL,
	[Event3A] [nvarchar](20) NOT NULL,
	[CreateDate] [datetime] NOT NULL,
	[OrdinalMean] [float] NULL,
	[OrdinalStDev] [float] NULL,
	[Skew] [float] NULL,
 CONSTRAINT [PK_ModelEvents] PRIMARY KEY NONCLUSTERED 
(
	[ModelID] ASC,
	[EventA] ASC,
	[EventB] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[ModelProperties]    Script Date: 4/8/2026 9:44:54 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ModelProperties](
	[PropertyName] [nvarchar](20) NOT NULL,
	[ModelID] [int] NOT NULL,
	[PropertyValueNumeric] [float] NULL,
	[CaseLevel] [bit] NOT NULL,
	[PropertyValueAlpha] [nvarchar](1000) NULL,
 CONSTRAINT [PK_ModelProperties] PRIMARY KEY CLUSTERED 
(
	[PropertyName] ASC,
	[ModelID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Models]    Script Date: 4/8/2026 9:44:54 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Models](
	[modelid] [int] IDENTITY(1,1) NOT NULL,
	[ModelType] [nvarchar](50) NOT NULL,
	[StartDateTime] [datetime] NULL,
	[EndDateTime] [datetime] NULL,
	[EventSetKey] [varbinary](16) NULL,
	[enumerate_multiple_events] [int] NOT NULL,
	[transformskey] [varbinary](16) NULL,
	[ByCase] [bit] NULL,
	[MetricID] [int] NULL,
	[CaseFilterProperties] [nvarchar](max) NULL,
	[AccessBitmap] [bigint] NULL,
	[Order] [int] NOT NULL,
	[CreateDate] [datetime] NULL,
	[EventFilterProperties] [nvarchar](max) NULL,
	[Description] [nvarchar](500) NULL,
	[IRI] [nvarchar](500) NULL,
	[DistinctCases] [int] NULL,
	[LastUpdate] [datetime] NULL,
	[CreationDuration] [int] NULL,
	[EventFactRows] [bigint] NULL,
	[ParamHash] [varbinary](16) NULL,
	[CreatedBy_AccessBitmap] [bigint] NULL,
 CONSTRAINT [PK_Models] PRIMARY KEY CLUSTERED 
(
	[modelid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[ModelSequences]    Script Date: 4/8/2026 9:44:54 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ModelSequences](
	[Seq] [nvarchar](2000) NULL,
	[lastEvent] [nvarchar](20) NULL,
	[nextEvent] [nvarchar](20) NULL,
	[SeqStDev] [float] NULL,
	[SeqMax] [float] NULL,
	[SeqAvg] [float] NULL,
	[SeqMin] [float] NULL,
	[SeqSum] [float] NULL,
	[HopStDev] [float] NULL,
	[HopMax] [float] NULL,
	[HopAvg] [float] NULL,
	[HopMin] [float] NULL,
	[TotalRows] [int] NULL,
	[Rows] [int] NULL,
	[Prob] [float] NULL,
	[TermRows] [int] NULL,
	[Cases] [int] NULL,
	[ModelID] [int] NOT NULL,
	[SeqKey] [varbinary](16) NOT NULL,
	[length] [int] NOT NULL,
	[CreateDate] [datetime] NOT NULL,
 CONSTRAINT [PK_ModelSequences] PRIMARY KEY CLUSTERED 
(
	[ModelID] ASC,
	[SeqKey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[ModelSimilarity]    Script Date: 4/8/2026 9:44:54 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ModelSimilarity](
	[ModelID1] [int] NOT NULL,
	[ModelID2] [int] NOT NULL,
	[CombinedUniqueSegments] [int] NOT NULL,
	[PercentSameSegments] [float] NULL,
	[Model1Segments] [int] NULL,
	[Model2Segments] [int] NULL,
	[SameSegments_ttest] [float] NULL,
	[IsMutuallyExclusive] [bit] NULL,
	[CosineSimilarity] [float] NULL,
 CONSTRAINT [PK_ModelSimilarity] PRIMARY KEY CLUSTERED 
(
	[ModelID1] ASC,
	[ModelID2] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[ProcErrorLog]    Script Date: 4/8/2026 9:44:54 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ProcErrorLog](
	[ErrorLogID] [int] IDENTITY(1,1) NOT NULL,
	[ProcedureName] [sysname] NOT NULL,
	[EventName] [nvarchar](20) NULL,
	[PropertyName] [nvarchar](20) NULL,
	[MetricName] [nvarchar](20) NULL,
	[ErrorNumber] [int] NULL,
	[ErrorMessage] [nvarchar](4000) NULL,
	[ErrorLine] [int] NULL,
	[LoggedAt] [datetime2](7) NULL,
	[ID] [bigint] NULL,
	[binaryID] [varbinary](16) NULL,
PRIMARY KEY CLUSTERED 
(
	[ErrorLogID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[SimilarSourceColumnPairs]    Script Date: 4/8/2026 9:44:54 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SimilarSourceColumnPairs](
	[SourceColumnID1] [int] NOT NULL,
	[SourceColumnID2] [int] NOT NULL,
	[SimilarityScore] [decimal](5, 4) NOT NULL,
	[Reason] [nvarchar](500) NULL
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[SourceColumns]    Script Date: 4/8/2026 9:44:54 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SourceColumns](
	[SourceColumnID] [int] IDENTITY(1,1) NOT NULL,
	[SourceID] [int] NULL,
	[TableName] [nvarchar](150) NULL,
	[ColumnName] [nvarchar](50) NOT NULL,
	[IsKey] [bit] NOT NULL,
	[IsOrdinal] [bit] NOT NULL,
	[DataType] [nchar](10) NULL,
	[Description] [nvarchar](500) NULL,
	[IRI] [nvarchar](500) NULL,
	[ObserverID] [bigint] NULL,
 CONSTRAINT [PK_SourceColumns] PRIMARY KEY CLUSTERED 
(
	[SourceColumnID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Sources]    Script Date: 4/8/2026 9:44:54 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Sources](
	[SourceID] [int] IDENTITY(1,1) NOT NULL,
	[Description] [nvarchar](500) NULL,
	[SourceProperties] [nvarchar](max) NULL,
	[Name] [nvarchar](50) NOT NULL,
	[DefaultTableName] [nvarchar](128) NULL,
	[IRI] [nvarchar](500) NULL,
	[DatabaseName] [nvarchar](400) NULL,
	[ServerName] [nvarchar](400) NULL,
	[PropertiesJSONFullyQualifiedColumnName] [nvarchar](128) NULL,
	[TargetJSONFullyQualifiedColumnName] [nvarchar](128) NULL,
	[DefaultObserverID] [bigint] NULL,
	[AccessBitmap] [bigint] NULL,
 CONSTRAINT [PK_Sources] PRIMARY KEY CLUSTERED 
(
	[SourceID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[TimeSolutionsMetadata]    Script Date: 4/8/2026 9:44:54 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[TimeSolutionsMetadata](
	[ObjectType] [nvarchar](60) NULL,
	[ObjectName] [nvarchar](517) NULL,
	[Description] [nvarchar](max) NULL,
	[Utilization] [nvarchar](4000) NULL,
	[ParametersJson] [nvarchar](max) NULL,
	[OutputNotes] [nvarchar](max) NULL,
	[ReferencedObjectsJson] [nvarchar](max) NULL,
	[IRI] [nvarchar](1000) NULL,
	[CodeColumn] [nvarchar](128) NULL,
	[Code] [nvarchar](50) NULL,
	[AccessBitmap] [bigint] NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Transforms]    Script Date: 4/8/2026 9:44:54 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Transforms](
	[transformskey] [varbinary](16) NOT NULL,
	[transforms] [nvarchar](max) NOT NULL,
	[Code] [nvarchar](20) NULL,
	[CreateDate] [datetime] NULL,
	[CreatedByUserID] [int] NULL,
	[Description] [nvarchar](500) NULL,
	[LastUpdate] [datetime] NULL,
	[AccessBitmap] [bigint] NULL,
 CONSTRAINT [PK_Transforms] PRIMARY KEY CLUSTERED 
(
	[transformskey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Users]    Script Date: 4/8/2026 9:44:54 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Users](
	[SUSER_NAME] [nvarchar](50) NOT NULL,
	[AccessBitmap] [bigint] NOT NULL,
	[UserID] [int] IDENTITY(1,1) NOT NULL,
	[CreateDate] [datetime] NULL,
	[LastUpdate] [datetime] NOT NULL,
	[Description] [nvarchar](500) NULL,
	[IRI] [nvarchar](500) NULL,
 CONSTRAINT [PK_Users] PRIMARY KEY CLUSTERED 
(
	[SUSER_NAME] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [STAGE].[ImportEvents]    Script Date: 4/8/2026 9:44:54 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [STAGE].[ImportEvents](
	[SourceID] [int] NOT NULL,
	[CaseID] [nvarchar](1000) NOT NULL,
	[Event] [nvarchar](50) NOT NULL,
	[EventDescription] [nvarchar](500) NULL,
	[EventDate] [nvarchar](30) NOT NULL,
	[CaseProperties] [nvarchar](max) NULL,
	[CaseTargetProperties] [nvarchar](max) NULL,
	[EventActualProperties] [nvarchar](max) NULL,
	[EventExpectedProperties] [nvarchar](max) NULL,
	[EventAggregationProperties] [nvarchar](max) NULL,
	[EventIntendedProperties] [nvarchar](max) NULL,
	[DateAdded] [datetime] NOT NULL,
	[AccessBitmap] [bigint] NOT NULL,
	[CaseType] [nvarchar](50) NULL,
	[NaturalKey_SourceColumnID] [int] NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [STAGE].[sales_event_data]    Script Date: 4/8/2026 9:44:54 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [STAGE].[sales_event_data](
	[sale_dollars] [float] NOT NULL,
	[datekey] [date] NOT NULL,
	[Sales_Event] [nvarchar](50) NOT NULL,
	[SourceID] [tinyint] NOT NULL,
	[Measure] [nvarchar](50) NOT NULL,
	[dice] [nvarchar](50) NOT NULL,
	[product_class] [nvarchar](50) NOT NULL,
	[Store] [nvarchar](50) NOT NULL,
	[QueryDefID] [nvarchar](150) NOT NULL,
	[startDate] [date] NOT NULL,
	[endDate] [date] NOT NULL,
	[CaseTypeName] [nvarchar](50) NOT NULL,
	[SourceServer] [nvarchar](50) NOT NULL,
	[SourceCatalog] [nvarchar](50) NOT NULL,
	[SourceSchema] [nvarchar](50) NOT NULL
) ON [PRIMARY]
GO
/****** Object:  Table [WORK].[BayesianProbability]    Script Date: 4/8/2026 9:44:54 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [WORK].[BayesianProbability](
	[SessionID] [uniqueidentifier] NOT NULL,
	[EventSetKeyA] [varbinary](16) NULL,
	[EventSetKeyB] [varbinary](16) NULL,
	[ACount] [int] NULL,
	[BCount] [int] NULL,
	[A_Int_BCount] [int] NULL,
	[PB|A] [float] NULL,
	[PA|B] [float] NULL,
	[TotalCases] [int] NULL,
	[PA] [float] NULL,
	[PB] [float] NULL
) ON [PRIMARY]
GO
/****** Object:  Table [WORK].[CaseCharacteristics]    Script Date: 4/8/2026 9:44:54 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [WORK].[CaseCharacteristics](
	[ModelID] [int] NULL,
	[CaseID] [int] NOT NULL,
	[EventIDA] [int] NULL,
	[EventIDB] [int] NULL,
	[Category] [nvarchar](50) NOT NULL,
	[Attribute] [nvarchar](50) NOT NULL,
	[EventA] [nvarchar](20) NULL,
	[EventB] [nvarchar](20) NULL,
	[metric_zscore] [float] NULL,
	[metric_value] [float] NULL,
	[transistion_prob] [float] NULL,
	[EventAIsEntry] [bit] NULL,
	[EventBIsExit] [bit] NULL,
	[PropertyValueNumeric] [float] NULL,
	[PropertyValueAlpha] [nvarchar](1000) NULL,
	[SessionID] [uniqueidentifier] NOT NULL
) ON [PRIMARY]
GO
/****** Object:  Table [WORK].[causeandeffectdetails]    Script Date: 4/8/2026 9:44:54 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [WORK].[causeandeffectdetails](
	[EventB] [nvarchar](50) NULL,
	[EventA] [nvarchar](50) NULL,
	[Player] [nvarchar](1000) NULL,
	[EventBID] [bigint] NULL,
	[EventAID] [bigint] NULL
) ON [PRIMARY]
GO
/****** Object:  Table [WORK].[DrillThroughToModelEvents]    Script Date: 4/8/2026 9:44:54 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [WORK].[DrillThroughToModelEvents](
	[CaseID] [int] NOT NULL,
	[Event] [nvarchar](20) NOT NULL,
	[EventDate] [datetime] NOT NULL,
	[Rank] [int] NOT NULL,
	[EventOccurence] [bigint] NOT NULL,
	[MetricActualValue] [float] NULL,
	[MetricExpectedValue] [float] NULL,
	[SessionID] [uniqueidentifier] NULL
) ON [PRIMARY]
GO
/****** Object:  Table [WORK].[MarkovProcess]    Script Date: 4/8/2026 9:44:54 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [WORK].[MarkovProcess](
	[ModelID] [int] NULL,
	[Event1A] [varchar](255) NULL,
	[Event2A] [varchar](255) NULL,
	[Event3A] [varchar](255) NULL,
	[EventB] [varchar](255) NULL,
	[Max] [decimal](18, 2) NULL,
	[Avg] [decimal](18, 2) NULL,
	[Min] [decimal](18, 2) NULL,
	[StDev] [decimal](18, 2) NULL,
	[CoefVar] [decimal](18, 2) NULL,
	[Sum] [decimal](18, 2) NULL,
	[Rows] [int] NULL,
	[Prob] [decimal](18, 4) NULL,
	[IsEntry] [int] NULL,
	[IsExit] [int] NULL,
	[FromCache] [int] NULL,
	[OrdinalMean] [decimal](18, 2) NULL,
	[OrdinalStDev] [decimal](18, 2) NULL,
	[SessionID] [uniqueidentifier] NULL
) ON [PRIMARY]
GO
/****** Object:  Table [WORK].[ModelDrillThrough]    Script Date: 4/8/2026 9:44:54 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [WORK].[ModelDrillThrough](
	[SessionID] [uniqueidentifier] NOT NULL,
	[CaseID] [int] NOT NULL,
	[EventA] [nvarchar](50) NULL,
	[EventB] [nvarchar](50) NULL,
	[EventDate_A] [datetime] NULL,
	[EventDate_B] [datetime] NULL,
	[Minutes] [float] NULL,
	[Rank] [int] NULL,
	[EventOccurence] [int] NULL,
	[EventA_ID] [int] NULL,
	[EventB_ID] [int] NULL,
	[EventA_SourceColumnID] [int] NULL,
	[EventB_SourceColumnID] [int] NULL
) ON [PRIMARY]
GO
/****** Object:  Table [WORK].[SelectedEvents]    Script Date: 4/8/2026 9:44:54 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [WORK].[SelectedEvents](
	[SessionID] [uniqueidentifier] NULL,
	[CaseID] [int] NULL,
	[Event] [nvarchar](20) NULL,
	[EventDate] [datetime] NULL,
	[Rank] [int] NULL,
	[EventOccurence] [bigint] NULL,
	[MetricInputValue] [float] NULL,
	[MetricOutputValue] [float] NULL,
	[EventID] [int] NULL
) ON [PRIMARY]
GO
/****** Object:  Table [WORK].[semantic_web_llm_values]    Script Date: 4/8/2026 9:44:54 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [WORK].[semantic_web_llm_values](
	[ObjectName] [nvarchar](500) NULL,
	[ObjectType] [nvarchar](50) NULL,
	[Description] [nvarchar](max) NULL,
	[Utilization] [nvarchar](max) NULL,
	[IRI] [nvarchar](1000) NULL,
	[CodeColumn] [nvarchar](128) NULL,
	[Code] [nvarchar](50) NULL,
	[AccessBitmap] [bigint] NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [WORK].[Sequences]    Script Date: 4/8/2026 9:44:54 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [WORK].[Sequences](
	[Seq] [nvarchar](2000) NULL,
	[lastEvent] [nvarchar](20) NULL,
	[nextEvent] [nvarchar](20) NULL,
	[SeqStDev] [float] NULL,
	[SeqMax] [float] NULL,
	[SeqAvg] [float] NULL,
	[SeqMin] [float] NULL,
	[SeqSum] [float] NULL,
	[HopStDev] [float] NULL,
	[HopMax] [float] NULL,
	[HopAvg] [float] NULL,
	[HopMin] [float] NULL,
	[TotalRows] [int] NULL,
	[Rows] [int] NULL,
	[Prob] [float] NULL,
	[ExitRows] [int] NULL,
	[Cases] [int] NULL,
	[ModelID] [int] NULL,
	[FromCache] [bit] NULL,
	[length] [int] NULL,
	[SessionID] [uniqueidentifier] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[AggregationTypes] ADD  CONSTRAINT [DF_AggregationTypes_IsNative]  DEFAULT ((1)) FOR [IsNative]
GO
ALTER TABLE [dbo].[BayesianProbabilities] ADD  CONSTRAINT [DF_BayesianProbabilities_CaseType]  DEFAULT (N'CASEID') FOR [GroupType]
GO
ALTER TABLE [dbo].[BayesianProbabilities] ADD  CONSTRAINT [DF_BayesianProbabilities_CreateDate]  DEFAULT (getdate()) FOR [CreateDate]
GO
ALTER TABLE [dbo].[BayesianProbabilities] ADD  CONSTRAINT [DF_BayesianProbabilities_AnomalyCategoryIDA]  DEFAULT ((-1)) FOR [AnomalyCategoryIDA]
GO
ALTER TABLE [dbo].[BayesianProbabilities] ADD  CONSTRAINT [DF_BayesianProbabilities_AnomalyCategoryIDB]  DEFAULT ((-1)) FOR [AnomalyCategoryIDB]
GO
ALTER TABLE [dbo].[BayesianProbabilities] ADD  CONSTRAINT [DF_BayesianProbabilities_LastUpdate]  DEFAULT (getdate()) FOR [LastUpdate]
GO
ALTER TABLE [dbo].[CaseProperties] ADD  CONSTRAINT [DF_CaseProperties_CreateDate]  DEFAULT (getdate()) FOR [CreateDate]
GO
ALTER TABLE [dbo].[CasePropertiesMDM] ADD  CONSTRAINT [DF_CasePropertiesMDM_CreateDate]  DEFAULT (getdate()) FOR [CreateDate]
GO
ALTER TABLE [dbo].[CasePropertiesMDM] ADD  CONSTRAINT [DF_CasePropertiesMDM_LastUpdate]  DEFAULT (getdate()) FOR [LastUpdate]
GO
ALTER TABLE [dbo].[CasePropertiesMDM] ADD  CONSTRAINT [DF_CasePropertiesMDM_MDMVersionID]  DEFAULT ((-1)) FOR [MDMVersionID]
GO
ALTER TABLE [dbo].[CasePropertiesMDM] ADD  CONSTRAINT [DF_CasePropertiesMDM_SimilarityScore]  DEFAULT ((1.0)) FOR [SimilarityScore]
GO
ALTER TABLE [dbo].[CasePropertiesMDM] ADD  CONSTRAINT [DF_CasePropertiesMDM_MDMComparisonType]  DEFAULT ((1)) FOR [MDMComparisonTypeID]
GO
ALTER TABLE [dbo].[CasePropertiesParsed] ADD  CONSTRAINT [DF_CasePropertiesParsed_AddedProperty]  DEFAULT ((0)) FOR [AddedProperty]
GO
ALTER TABLE [dbo].[CasePropertiesParsed] ADD  CONSTRAINT [DF_CasePropertiesParsed_CreateDate]  DEFAULT (getdate()) FOR [CreateDate]
GO
ALTER TABLE [dbo].[CasePropertiesParsed] ADD  CONSTRAINT [DF_CasePropertiesParsed_LastUpdate]  DEFAULT (getdate()) FOR [LastUpdate]
GO
ALTER TABLE [dbo].[Cases] ADD  CONSTRAINT [DF_Cases_EventCount]  DEFAULT ((0)) FOR [EventCount]
GO
ALTER TABLE [dbo].[Cases] ADD  CONSTRAINT [DF_Cases_CreateDate]  DEFAULT (getdate()) FOR [CreateDate]
GO
ALTER TABLE [dbo].[DimEvents] ADD  CONSTRAINT [DF_DimEvents_CreateDate]  DEFAULT (getdate()) FOR [CreateDate]
GO
ALTER TABLE [dbo].[DimEvents] ADD  CONSTRAINT [DF_DimEvents_LastUpdated]  DEFAULT (getdate()) FOR [LastUpdated]
GO
ALTER TABLE [dbo].[DimEvents] ADD  CONSTRAINT [DF_DimEvents_SourceID]  DEFAULT ((0)) FOR [SourceID]
GO
ALTER TABLE [dbo].[DimEvents] ADD  CONSTRAINT [DF_DimEvents_IsState]  DEFAULT ((0)) FOR [IsState]
GO
ALTER TABLE [dbo].[EventPairAnomalies] ADD  CONSTRAINT [DF_EventPairAnomalies_EventAIsEntry]  DEFAULT ((0)) FOR [EventAIsEntry]
GO
ALTER TABLE [dbo].[EventPairAnomalies] ADD  CONSTRAINT [DF_EventPairAnomalies_EventBIsExit]  DEFAULT ((0)) FOR [EventBIsExit]
GO
ALTER TABLE [dbo].[EventPairAnomalies] ADD  CONSTRAINT [DF_EventPairAnomalies_CreateDate]  DEFAULT (getdate()) FOR [CreateDate]
GO
ALTER TABLE [dbo].[EventProperties] ADD  CONSTRAINT [DF_EventProperties_LastUpdated]  DEFAULT (getdate()) FOR [LastUpdated]
GO
ALTER TABLE [dbo].[EventProperties] ADD  CONSTRAINT [DF_EventProperties_CreateDate]  DEFAULT (getdate()) FOR [CreateDate]
GO
ALTER TABLE [dbo].[EventPropertiesMDM] ADD  CONSTRAINT [DF_EventPropertiesMDM_CreateDate]  DEFAULT (getdate()) FOR [CreateDate]
GO
ALTER TABLE [dbo].[EventPropertiesMDM] ADD  CONSTRAINT [DF_EventPropertiesMDM_LastUpdate]  DEFAULT (getdate()) FOR [LastUpdate]
GO
ALTER TABLE [dbo].[EventPropertiesMDM] ADD  CONSTRAINT [DF_EventPropertiesMDM_SimilarityScore]  DEFAULT ((1.0)) FOR [SimilarityScore]
GO
ALTER TABLE [dbo].[EventPropertiesMDM] ADD  CONSTRAINT [DF_EventPropertiesMDM_MDMComparisonTypeID]  DEFAULT ((1)) FOR [MDMComparisonTypeID]
GO
ALTER TABLE [dbo].[EventPropertiesParsed] ADD  CONSTRAINT [DF_EventPropertiesParsed_PropertySource]  DEFAULT ((0)) FOR [PropertySource]
GO
ALTER TABLE [dbo].[EventPropertiesParsed] ADD  CONSTRAINT [DF_EventPropertiesParsed_CreateDate]  DEFAULT (getdate()) FOR [CreateDate]
GO
ALTER TABLE [dbo].[EventPropertiesParsed] ADD  CONSTRAINT [DF_EventPropertiesParsed_LastUpdate]  DEFAULT (getdate()) FOR [LastUpdate]
GO
ALTER TABLE [dbo].[EventSets] ADD  CONSTRAINT [DF_EventSets_MustBeOrdered]  DEFAULT ((0)) FOR [IsSequence]
GO
ALTER TABLE [dbo].[EventSets] ADD  CONSTRAINT [DF_EventSets_CreateDate]  DEFAULT (getdate()) FOR [CreateDate]
GO
ALTER TABLE [dbo].[EventSets] ADD  CONSTRAINT [DF_EventSets_LastUpdate]  DEFAULT (getdate()) FOR [LastUpdate]
GO
ALTER TABLE [dbo].[EventSets] ADD  CONSTRAINT [DF_EventSets_IsCaseProperty]  DEFAULT ((0)) FOR [IsCaseProperty]
GO
ALTER TABLE [dbo].[EventsFact] ADD  CONSTRAINT [DF_EventsFact_EventDate]  DEFAULT (getdate()) FOR [EventDate]
GO
ALTER TABLE [dbo].[EventsFact] ADD  CONSTRAINT [DF_EventsFact_CreateDate]  DEFAULT (getdate()) FOR [CreateDate]
GO
ALTER TABLE [dbo].[Model_Stationary_Distribution] ADD  CONSTRAINT [DF_Model_Stationary_Distribution_CreateDate]  DEFAULT (getdate()) FOR [CreateDate]
GO
ALTER TABLE [dbo].[ModelEvents] ADD  CONSTRAINT [DF_ModelEvents_IsEntry]  DEFAULT ((0)) FOR [IsEntry]
GO
ALTER TABLE [dbo].[ModelEvents] ADD  CONSTRAINT [DF_ModelEvents_IsExit]  DEFAULT ((0)) FOR [IsExit]
GO
ALTER TABLE [dbo].[ModelEvents] ADD  CONSTRAINT [DF_ModelEvents_CreateDate]  DEFAULT (getdate()) FOR [CreateDate]
GO
ALTER TABLE [dbo].[ModelProperties] ADD  CONSTRAINT [DF_ModelProperties_CaseLevel]  DEFAULT ((1)) FOR [CaseLevel]
GO
ALTER TABLE [dbo].[Models] ADD  CONSTRAINT [DF_Models_ModelType]  DEFAULT (N'MarkovChain') FOR [ModelType]
GO
ALTER TABLE [dbo].[Models] ADD  CONSTRAINT [DF_Models_enumerate_multiple_events]  DEFAULT ((0)) FOR [enumerate_multiple_events]
GO
ALTER TABLE [dbo].[Models] ADD  CONSTRAINT [DF_Models_ByCase]  DEFAULT ((1)) FOR [ByCase]
GO
ALTER TABLE [dbo].[Models] ADD  CONSTRAINT [DF_Models_Order]  DEFAULT ((1)) FOR [Order]
GO
ALTER TABLE [dbo].[Models] ADD  CONSTRAINT [DF_Models_CreateDate]  DEFAULT (getdate()) FOR [CreateDate]
GO
ALTER TABLE [dbo].[Models] ADD  CONSTRAINT [DF_Models_LastUpdate]  DEFAULT (getdate()) FOR [LastUpdate]
GO
ALTER TABLE [dbo].[ModelSequences] ADD  CONSTRAINT [DF_ModelSequences_CreateDate]  DEFAULT (getdate()) FOR [CreateDate]
GO
ALTER TABLE [dbo].[ProcErrorLog] ADD  DEFAULT (sysutcdatetime()) FOR [LoggedAt]
GO
ALTER TABLE [dbo].[SourceColumns] ADD  CONSTRAINT [DF_SourceColumns_IsKey]  DEFAULT ((0)) FOR [IsKey]
GO
ALTER TABLE [dbo].[SourceColumns] ADD  CONSTRAINT [DF_SourceColumns_Continuous]  DEFAULT ((0)) FOR [IsOrdinal]
GO
ALTER TABLE [dbo].[SourceColumns] ADD  CONSTRAINT [DF_SourceColumns_DataType]  DEFAULT (N'nvarchar') FOR [DataType]
GO
ALTER TABLE [dbo].[Sources] ADD  CONSTRAINT [DF_Sources_AccessBitmap]  DEFAULT ((0)) FOR [AccessBitmap]
GO
ALTER TABLE [dbo].[Transforms] ADD  CONSTRAINT [DF_Transforms_CreateDate]  DEFAULT (getdate()) FOR [CreateDate]
GO
ALTER TABLE [dbo].[Transforms] ADD  CONSTRAINT [DF_Transforms_LastUpdate]  DEFAULT (getdate()) FOR [LastUpdate]
GO
ALTER TABLE [dbo].[Transforms] ADD  CONSTRAINT [DF_Transforms_AccessBitmap]  DEFAULT ((-1)) FOR [AccessBitmap]
GO
ALTER TABLE [dbo].[Users] ADD  CONSTRAINT [DF_Users_AccessBitmap]  DEFAULT ((0)) FOR [AccessBitmap]
GO
ALTER TABLE [dbo].[Users] ADD  CONSTRAINT [DF_Users_CreateDate]  DEFAULT (getdate()) FOR [CreateDate]
GO
ALTER TABLE [dbo].[Users] ADD  CONSTRAINT [DF_Users_LastUpdate]  DEFAULT (getdate()) FOR [LastUpdate]
GO
ALTER TABLE [STAGE].[ImportEvents] ADD  CONSTRAINT [DF_ImportEvents_DateAdded]  DEFAULT (getdate()) FOR [DateAdded]
GO
ALTER TABLE [STAGE].[ImportEvents] ADD  CONSTRAINT [DF_ImportEvents_AccessBitmap]  DEFAULT ((-1)) FOR [AccessBitmap]
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'0=Aggregation is custom,  some ETL package.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AggregationTypes', @level2type=N'COLUMN',@level2name=N'IsNative'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'This is a json of metadata regarding the aggregation. It can include things such as the ETL package, function, or program that created it, and required parameters.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AggregationTypes', @level2type=N'COLUMN',@level2name=N'Metadata'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'An EventFact could be an aggregation of a type of event. For example, if an IoT device sends very many events during the day, say on an hourly basis, we might want to compare data on just some daily calculation such as last value or max value.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AggregationTypes'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'We can group events as cases, days, months, year.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'BayesianProbabilities', @level2type=N'COLUMN',@level2name=N'GroupType'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Allow a null in case we don''t have this value.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'BayesianProbabilities', @level2type=N'COLUMN',@level2name=N'ACount'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Allow a null in case we don''t have this value.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'BayesianProbabilities', @level2type=N'COLUMN',@level2name=N'BCount'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Allow a null in case we don''t have this value.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'BayesianProbabilities', @level2type=N'COLUMN',@level2name=N'A_Int_BCount'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Allow a null in case we don''t have this value.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'BayesianProbabilities', @level2type=N'COLUMN',@level2name=N'PB|A'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Stores a calculated conditional probability.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'BayesianProbabilities'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Properties related to what we targeted for the case.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'CaseProperties', @level2type=N'COLUMN',@level2name=N'TargetProperties'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'This is decoupled from the Cases table because it''s JSON that is more of a storage than used at query time. CasePropertiesParsed is a relational table (key/value).' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'CaseProperties'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'There can be many "MDM" mappings. This MDMVersionID allows for multiple mappings. The -1 default is the default mapping that will be transformed at the time CasePropertiesParsed is created.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'CasePropertiesMDM', @level2type=N'COLUMN',@level2name=N'MDMVersionID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'See MDMComparisonType table.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'CasePropertiesMDM', @level2type=N'COLUMN',@level2name=N'MDMComparisonTypeID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'The PK of SourceColumnID, PropertyName, MDMSourceColumnID means there is one row for each mapping' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'CasePropertiesMDM', @level2type=N'CONSTRAINT',@level2name=N'PK_CasePropertiesMDM'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'When CaseProperties are parsed into CasePropertiesParsed, they are transformed to a common MDM value.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'CasePropertiesMDM'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'JSON bag of properties.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'CasePropertiesParsed', @level2type=N'COLUMN',@level2name=N'CaseID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Case-level properties. This is anything related to the property. For example, the customer id, the employee id of the person who served the customer. These could be used to slice and dice the cases.

This is a JSON field. This is to allow for a heterogeneous mix of case and event types.

For BI performance purposes, the implementor can select five of these properties to be denormalized into the Cases table. This avoids query-time parsing of JSON and joins. 

TargetProperties are a special set of properties for which we track something at the case level. See the description for the TargetProperties column..' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'CasePropertiesParsed', @level2type=N'COLUMN',@level2name=N'PropertyName'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Case-level properties intended to be things that will be the target values of analysis.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'CasePropertiesParsed', @level2type=N'COLUMN',@level2name=N'PropertyValueNumeric'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'0=This was parsed out of CaseProperties, 1=Added outside of case properties. CaseProperties is silver-level, cleansed table, not added.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'CasePropertiesParsed', @level2type=N'COLUMN',@level2name=N'AddedProperty'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'A value that allows the propertyname to be sorted. It comes from the property json:

{"Sizes": {"value": "large", "sort_value": 5}' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'CasePropertiesParsed', @level2type=N'COLUMN',@level2name=N'SortValue'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Case properties that are in JSON in the CaseProperties table, are flattened into one row per case property to avoid run-time json parsing. It also stores some data redundantly (StartDateTime, EndDateTime) to this table could act as a kind of covering index to narrow the property space without joining to the Cases table.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'CasePropertiesParsed'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Bitmap of Access. Cases included in a markov model must match the access. Inherits from CaseType AccessBitMap. In turn, EventsFact inherits this as well.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Cases', @level2type=N'COLUMN',@level2name=N'AccessBitmap'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'NaturalKey of the Case. This could be a json because the natural key could be made of parts. This should be the CaseID column from STAGE.ImportEevnts.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Cases', @level2type=N'COLUMN',@level2name=N'NaturalKey'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'The SourceColumns.SourceID for the event column of EventsFact rows under this CaseID.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Cases', @level2type=N'COLUMN',@level2name=N'Event_SourceColumnID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'The SourceColumns.SourceID for the date column of EventsFact rows under this CaseID.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Cases', @level2type=N'COLUMN',@level2name=N'Date_SourceColumnID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'The SourceColumns.SourceID for the natural key column of this case.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Cases', @level2type=N'COLUMN',@level2name=N'NaturalKey_SourceColumnID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Intended as a prompt to an LLM so we can obtain more information about this.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'CaseTypes', @level2type=N'COLUMN',@level2name=N'Description'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'The IRI (Internation Resource Identifier) is the gateway to a knowledge graph.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'CaseTypes', @level2type=N'COLUMN',@level2name=N'IRI'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Cases inherit this AccessBitmap. In turn, events inherit from the case. Each event access could be modified.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'CaseTypes', @level2type=N'COLUMN',@level2name=N'AccessBitmap'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Hierarchy of Case Types' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'CaseTypes'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'The IRI (Internation Resource Identifier) is the gateway to a knowledge graph.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DimAnomalyCategories', @level2type=N'COLUMN',@level2name=N'IRI'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Intended as a prompt to an LLM so we can obtain more information about this.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DimEvents', @level2type=N'COLUMN',@level2name=N'Description'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'json document of properties. Intended to describe attributes of entities that are involved. In a Markov System.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DimEvents', @level2type=N'COLUMN',@level2name=N'Properties'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'The IRI (Internation Resource Identifier) is the gateway to a knowledge graph.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DimEvents', @level2type=N'COLUMN',@level2name=N'IRI'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'SourceID enables us to create events in a "namespace". This is so if different DWs or other sources have the same event with different meanings.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DimEvents', @level2type=N'COLUMN',@level2name=N'SourceID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Although the TimeMolecules events are events, we could create events that are really states. For example, in poker, after a player takes an action (an event), the state of the game changes. The next player (a good player) should react to the new state of the game, not the last action.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DimEvents', @level2type=N'COLUMN',@level2name=N'IsState'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'This data stores extra data on event codes - which I just refer to as events. That''s sort of confusing because an event is a fact, but the fields name event refer to a type of event.

Event codes of EventFact do not need to be in here. This is because new facts may come in. However, it''s good to have it here so that new sources know an event code already exists and so they should name the new event code something else.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DimEvents'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Code of the observer (generator of events).' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DimObservers', @level2type=N'COLUMN',@level2name=N'Code'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'The storage place of event generated by the observer. This is where the Events Ensemble reads the events. ' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DimObservers', @level2type=N'COLUMN',@level2name=N'SourceID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Observers are the devices (IoT, AI agents, cars, phones), and each can consist of a hierarchy of event emitters.

Note that Observers differ from Sources in that a Source is where case and event properties can be looked up.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DimObservers', @level2type=N'COLUMN',@level2name=N'Parent_ObserverID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Observer of events. Could be an IoT device, AI agent, person, or some sort of system. Differs from Sources, which are where EventFacts are stored, not generated.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DimObservers'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'JSON bag of properties.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'EventProperties', @level2type=N'COLUMN',@level2name=N'EventID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Metric inputs - key/value pairs of metrics as inputs into a node.

The idea behind InputProperties and OutputProperties is that something happens between entering the state and exiting. Things can also happen between exiting a state and entering another one.

See the table Metrics and the scalar function, MetricValue.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'EventProperties', @level2type=N'COLUMN',@level2name=N'ActualProperties'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Metric inputs - key/value pairs of metrics as Outputs from a node.

See description for InputProperties.

If the event just a reading, there shouldn''t be OutputProperties.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'EventProperties', @level2type=N'COLUMN',@level2name=N'ExpectedProperties'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'If an Event is an aggregation, these are the properties of the aggregation. Examples of keys would be the aggregator''s name, each descriptive statistic of the aggregation.

See the AggregationTypes table.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'EventProperties', @level2type=N'COLUMN',@level2name=N'AggregationProperties'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Actual vs. Expected (predicted) is the subject of statisticians creating the confusion matrix. Intended is what we''re shooting for.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'EventProperties', @level2type=N'COLUMN',@level2name=N'IntendedProperties'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'The function, a prolog, a rest call, etc. that triggered the function. The parameters could be in the ActualProperties.

The importance of knowing why the event trigged added reasoning and something that can help us adjust how the events are triggered.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'EventProperties', @level2type=N'COLUMN',@level2name=N'TriggerFunction'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'When EventProperties are parsed into EventPropertiesParsed, they are transformed to a common MDM value.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'EventPropertiesMDM'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'0 = ActualProperties, 1=ExpectedProperties, 2=AggregationProperties, 3=IntendedProperties' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'EventPropertiesParsed', @level2type=N'COLUMN',@level2name=N'PropertySource'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Count of properties for eventid. It''s used to allocate count, avoiding a distinct count.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'EventPropertiesParsed', @level2type=N'COLUMN',@level2name=N'EventPropertyCountAllocation'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Used like a covering index, so we can filter event properties better. Don''t need to do join from EventPropertiesParsed to EventFacts.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'EventPropertiesParsed', @level2type=N'COLUMN',@level2name=N'EventDate'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'CaseID will help for Azure Synapse deployment. The idea is to hash on CaseID and distrubte. That way, Cases, EventFacts, EventPropertiesParsed, and CasePropertiesParsed can be hash distributed by CaseID.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'EventPropertiesParsed', @level2type=N'COLUMN',@level2name=N'CaseID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Stores properties parsed out of the json value in the EventProperties tables. It stores a few pieces of data redundantly, acting as a sort of covering index (EventDate, Event, CaseID).' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'EventPropertiesParsed'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'4000 should be good for at least 200 event codes (each event code is NVARCHAR(20)).' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'EventSets', @level2type=N'COLUMN',@level2name=N'EventSet'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Allow NULL since we might not have a code, but want to preserve the key. The NULL values means we can''t set up an index on EventSetCode.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'EventSets', @level2type=N'COLUMN',@level2name=N'EventSetCode'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Normally, we want to find the set in whatever order it''s given, so to get a consistent key, the set should be ordered alphabetically. This means IsSequence=0.

However, if it is a specific order, such as a sequence of events, we need to get the key by that order. IsSequence=1.

For example, set {B,A,C} where IsSequence=0 would have {A,B,C}, {B,C,A}, {C,A,B}, (C,B,A} all refer to the same set. So in order to make sure we have the same key, we ironically sort it alphabetically and get the hash.

If we are talking about a sequence happening of {B,C,A}, they are different from the other combinations. So, we should not sort them. The has should be different for each permutation.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'EventSets', @level2type=N'COLUMN',@level2name=N'IsSequence'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Intended as a prompt to an LLM in order to help link information. For example, we could prompt the description of multiple event sets (or the set of Events - the list of events in EventSet) and ask how they relate.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'EventSets', @level2type=N'COLUMN',@level2name=N'Description'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'UserID of the author of the description. Could be ChatGPT or a person.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'EventSets', @level2type=N'COLUMN',@level2name=N'DescriptionAuthorUserID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Case Properties might be corellated with Anamolies in a Model. For example, big tips might be correlated with a short wait between arriving and being seated.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'EventSets', @level2type=N'COLUMN',@level2name=N'IsCaseProperty'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Number of items in EventSet. This is so we know which are just events (Length=1).' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'EventSets', @level2type=N'COLUMN',@level2name=N'Length'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Sets of Events that usually are included in a process, restricting what is included in a Markov Model. Differs from case types, which really define the process. The event set could be referenced by an EventSetCode. The events are in the EventSet column as a coma-separated list.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'EventSets'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Even a long-running case should have an ID. That would be like a feed from an IoT device that goes on indefinitely.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'EventsFact', @level2type=N'COLUMN',@level2name=N'CaseID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'There should always be an event, but it doesn''t need to be in the events table. It''s a case of allow an event that''s not in the events table and deal with it later.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'EventsFact', @level2type=N'COLUMN',@level2name=N'Event'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'The event might be an aggregation of smaller events compressed through a Streaming analytics port. If it is, information of the aggregation should be in the EventProperties.AggregationProperties field as a JSON.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'EventsFact', @level2type=N'COLUMN',@level2name=N'AggregationTypeID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Order of the event within the case.

The order is already defined by EventDate, but without ordinal, it''s hard to easily fetch the n-x or n+x, first row. 

This should be calculated for each case in the ETL using RANK.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'EventsFact', @level2type=N'COLUMN',@level2name=N'CaseOrdinal'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'This is used to connect sub-processes to a parent case.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'EventsFact', @level2type=N'COLUMN',@level2name=N'ParentCaseID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'An ID that could be used to delete events, eventproperties, case, case properties. See Delete_Batch sproc.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'EventsFact', @level2type=N'COLUMN',@level2name=N'BatchID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'At import, the event should inherit from a sum of Case and DimEvent AccessBitmap. This ensures we''re secured at the lowest granularity.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'EventsFact', @level2type=N'COLUMN',@level2name=N'AccessBitmap'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Central table of the Event Ensemble of Time Solution. All events are stored here, and Markov models and bayesian probabilities are created from this.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'EventsFact'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Applies to the CasePropertiesMDM and EventPropertiesMDM tables. Those two tables hold a "golden value" for case and event properties, respectively. Some, such as GPS coordinates probably will not be exact, so we assign a value between 0-1. For the case of GPS coordinates, it''s a distance which should be normalized into a value between 0-1.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'MDMComparisonTypes'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'See dbo.MarkovChain to see how this is applied. ex: 0=EventBInput-EventAOutput, 1=EventBInput-EventAInput' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Metrics', @level2type=N'COLUMN',@level2name=N'Method'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Unit of Measure' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Metrics', @level2type=N'COLUMN',@level2name=N'UoM'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Intended as a prompt to an LLM so we can obtain more information about this.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Metrics', @level2type=N'COLUMN',@level2name=N'Description'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'1st Order Markov Models.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ModelEvents', @level2type=N'COLUMN',@level2name=N'ModelID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Coefficient of Variance - Statistical measure that represents the ratio of the standard deviation to the mean of a dataset, expressed as a percentage.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ModelEvents', @level2type=N'COLUMN',@level2name=N'CoefVar'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Probability of EventA to EventB. It is the number of times EventA transitions to EventB versus the total number of transitions of EventA to any other Event.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ModelEvents', @level2type=N'COLUMN',@level2name=N'Prob'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'How many times was this the entry point?' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ModelEvents', @level2type=N'COLUMN',@level2name=N'IsEntry'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'How many times was this the exit?' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ModelEvents', @level2type=N'COLUMN',@level2name=N'IsExit'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Many distibutions between events will be skewed. I think skewed left would be more common since i think things could take longer but can only be so fast (like zero seconds).

It actually requires yet another pass AFTER getting StDev (it needs StDev).' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ModelEvents', @level2type=N'COLUMN',@level2name=N'Skew'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Stores EventA -> EventB segments of a Markov model along with statistics between the events.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ModelEvents'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'This should actually be PropertyValue.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ModelProperties', @level2type=N'COLUMN',@level2name=N'PropertyValueNumeric'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'This is a property parsed out of Models.CaseFilterProperties. ' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ModelProperties', @level2type=N'COLUMN',@level2name=N'CaseLevel'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'A lookup table that signifies models that have a particular property in the Models.CaseFilterProperties and Models.EventFilterProperties JSON fields. This prevents needing to parse through those JSON fields at querytime to filter models.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ModelProperties'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Primary Key of the Models table. It''s a commonly used parameter.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Models', @level2type=N'COLUMN',@level2name=N'modelid'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'1. BayesianProbability - Conditional probability

2. MarkovChain - Created from event sets and event facts.

3. Workflow - This is an intended process. It may not even have events. Workflows could be made concrete from Markov Models. Workflows could also be decision trees, strategy maps.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Models', @level2type=N'COLUMN',@level2name=N'ModelType'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'0=Do Not transform multiple occurences of an event into event, event1, event2...
>0= This is how many events to transform. For example, if 3, event, event1, event2, event3, event3, event3 ...

There is a difference between an event happening 1 or event 2 times. But more than that probably doesn''t matter too much.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Models', @level2type=N'COLUMN',@level2name=N'enumerate_multiple_events'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'the effective access scope to use when selecting facts for that model run or model drill-through.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Models', @level2type=N'COLUMN',@level2name=N'AccessBitmap'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'1st order markov model elements are stored in ModelEvents.
2nd order markov model elements are stored in ModelEvents2.
3rd order markov model elements are stored in ModelEvents3.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Models', @level2type=N'COLUMN',@level2name=N'Order'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'A usually LLM-created description used to create an embedding of the model. We will provide to the LLM a table structure of eventA, eventB and description of eventA and eventB.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Models', @level2type=N'COLUMN',@level2name=N'Description'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Distinct cases.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Models', @level2type=N'COLUMN',@level2name=N'DistinctCases'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'In seconds, how long this model took to create.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Models', @level2type=N'COLUMN',@level2name=N'CreationDuration'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'EventsFact rows used to create this model.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Models', @level2type=N'COLUMN',@level2name=N'EventFactRows'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'This is a hash of the model-level parameters. This mostly helps to link Model events that are bayesian probabilities with markov models. This helps enable hidden markov model so we can link an event from a markov model to an event from a bayesian pair (specifically Event A).' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Models', @level2type=N'COLUMN',@level2name=N'ParamHash'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'a historical property of the model. “Under what access scope was this model originally created?”' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Models', @level2type=N'COLUMN',@level2name=N'CreatedBy_AccessBitmap'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'The primary table of the Markov Model ensemble of TimeSolution. This table holds the parameters of the markov models created from the events in dbo.EventFacts. The Markov model segments are in the ModelEvents table.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Models'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Standard deviation of time between the first event and lastEvent of the sequence.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ModelSequences', @level2type=N'COLUMN',@level2name=N'SeqStDev'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Standard deviation of time between lastEvent and nextEvent.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ModelSequences', @level2type=N'COLUMN',@level2name=N'HopStDev'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Total rows involved in calculating the sequence row.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ModelSequences', @level2type=N'COLUMN',@level2name=N'TotalRows'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'length of the sequence. This can be used to find the first occurance of a sequence part.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ModelSequences', @level2type=N'COLUMN',@level2name=N'length'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Stores statistics on sequences of events that actually have occurred, in the EventsFact table. For example, arrive->greeted->seated. It''s good to know how often a sequence happens, along with other information.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ModelSequences'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Percentage of EventA->EventB segments that are shared.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ModelSimilarity', @level2type=N'COLUMN',@level2name=N'PercentSameSegments'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Mutually exclusive means the cases comprising both models do not overlap.

NULL = Hasn''t been determined, 0 = No, 1 = Is Mututally exclusive.

If model are sliced from different partitions, the EventFacts comprising the models are mutually exclusive. If the models are mutually exclusive, they can be added.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ModelSimilarity', @level2type=N'COLUMN',@level2name=N'IsMutuallyExclusive'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Scores the difference between two markov models. This is one of the prime use cases for time molecules. This is done using the InsertModelSimilarities stored procedure.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ModelSimilarity'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'This looks at the SourceColumn table, along with values like the description and IRI of the column. There is a score for the similarity. See the python script: source_column_semantic_similarity.py, It uses an LLM to determine the score and reason. This is a very valuable feature that enables us to figure out processes by matching properties.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'SimilarSourceColumnPairs'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'ColumnName should be 50 because that''s the length I have for the "Name" of the table rows. See the get_semantic_web_llm_values sproc.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'SourceColumns', @level2type=N'COLUMN',@level2name=N'ColumnName'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Is this column ordinal (1) or discrete (0)? The column can be used to correlate changes in Markov models across values of this column. If the column is continuous, it''s considered ordinal.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'SourceColumns', @level2type=N'COLUMN',@level2name=N'IsOrdinal'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Leave this column NULL since we may not know the data type initially. Try to use SQL Server data types since this is a SQL Server database.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'SourceColumns', @level2type=N'COLUMN',@level2name=N'DataType'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Description of what the column is semantically about. This can be used to figure out an IRI RDF class that matches the meaning of this column.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'SourceColumns', @level2type=N'COLUMN',@level2name=N'Description'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'The IRI (Internation Resource Identifier) is the gateway to a knowledge graph.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'SourceColumns', @level2type=N'COLUMN',@level2name=N'IRI'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'A data source stores data observed by an observer. however, a data source might consist of multiple observers-like a person has multiple senses or a car has multiple devices emitting events.

AI agents could be an observer.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'SourceColumns', @level2type=N'COLUMN',@level2name=N'ObserverID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Metadata that traces properties, natural keys, etc. back to a source, in this case the table and column. This is usually from a semantic layer, but it can be the OLTP source if necessary.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'SourceColumns'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'It''s possible the source is "one big table" or a CSV. In this case, it helps to have the name of the table as a default.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Sources', @level2type=N'COLUMN',@level2name=N'DefaultTableName'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Name of source fully qualified column name (schema,table.column) containing JSON of case-level properties.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Sources', @level2type=N'COLUMN',@level2name=N'PropertiesJSONFullyQualifiedColumnName'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Name of source fully qualified column name (schema,table.column) containing JSON of case-level properties.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Sources', @level2type=N'COLUMN',@level2name=N'TargetJSONFullyQualifiedColumnName'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'A data source stores data observed by an observer. however, a data source might consist of multiple observers-like a person has multiple senses or a car has multiple devices emitting events.

This is the default observer.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Sources', @level2type=N'COLUMN',@level2name=N'DefaultObserverID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Sources are where events generated by observers are stored), and accessed by the EventEnsemble. 

Observer -> Source -> EventEnsemble -> Models' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Sources'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Intended as a prompt to an LLM in order to help link information. For example, we could prompt the description of multiple transformations (or the set of transforms - the json of mappings) and ask how they relate.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Transforms', @level2type=N'COLUMN',@level2name=N'Description'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Event Transforms - Events could be aggregated together.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Transforms'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Could be JSON of parts comprising the natural key.' , @level0type=N'SCHEMA',@level0name=N'STAGE', @level1type=N'TABLE',@level1name=N'ImportEvents', @level2type=N'COLUMN',@level2name=N'SourceID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Really, the naturalkey of the case. it will be imported as Case.NaturalKey.' , @level0type=N'SCHEMA',@level0name=N'STAGE', @level1type=N'TABLE',@level1name=N'ImportEvents', @level2type=N'COLUMN',@level2name=N'CaseID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'This is a flattened table, so all CaseProperties for a CaseID should be the same.' , @level0type=N'SCHEMA',@level0name=N'STAGE', @level1type=N'TABLE',@level1name=N'ImportEvents', @level2type=N'COLUMN',@level2name=N'CaseProperties'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'This is a flattened table, so all CaseTargetProperties for a CaseID should be the same.' , @level0type=N'SCHEMA',@level0name=N'STAGE', @level1type=N'TABLE',@level1name=N'ImportEvents', @level2type=N'COLUMN',@level2name=N'CaseTargetProperties'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Default of -1 means all bits are set.' , @level0type=N'SCHEMA',@level0name=N'STAGE', @level1type=N'TABLE',@level1name=N'ImportEvents', @level2type=N'COLUMN',@level2name=N'AccessBitmap'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Should be the same as CaseTypes.[Name], which is the "code" for case types.' , @level0type=N'SCHEMA',@level0name=N'STAGE', @level1type=N'TABLE',@level1name=N'ImportEvents', @level2type=N'COLUMN',@level2name=N'CaseType'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'This is the standard import table. everything should be loaded into this table.' , @level0type=N'SCHEMA',@level0name=N'STAGE', @level1type=N'TABLE',@level1name=N'ImportEvents'
GO
