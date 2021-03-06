

/*
I went down the route of breaking down everything into functions because this is good practice in JS and PHP for testing and layout etc.
but seems very slow to run in SQL and some functions seem a bit redundant. But the functions also mean that it would be pretty easy for
me to start extending the code to outpatients, A&E, maternity etc and include BPT so this is a plus. 
What's your opinion on this?

TODO: Add error handling for missing/incorrectly formatted bits of data in the HES data or the HRG tables

Extensions if time: Dynamically name tables for different years and then have an input that indicates which year you want to calculate
*/

USE nhsProject;
GO

--Function: Breaks downs admimeth into elective, non-elective or other types (could output ints like 1, 2, 3 etc. but this seemed more readable)
IF OBJECT_ID('hrg.admissionType') IS NOT NULL 
BEGIN
	DROP FUNCTION [hrg].admissionType
END

GO

create function [hrg].admissionType (@admimeth varchar(10))
RETURNS varchar(50)
AS
BEGIN
	DECLARE @admissionType varchar(50);
	IF @admimeth LIKE '1%' --Insert more specific regex and handle with error when not in right form?
		SET @admissionType = 'elective'
	ELSE IF @admimeth LIKE '2%'
		SET @admissionType = 'nonElective'
	ELSE IF @admimeth LIKE '3%'
		SET @admissionType = 'maternity' --Continue if time...left open ended for outpatients, A&E, maternity, BPT
	;
			
	RETURN @admissionType;
END

GO

--Function: indicates whether the combined day and ordinary case field has a value or not (maybe a little bit pointless but oh well)
IF OBJECT_ID('hrg.combinedDayOrdNotNull17_18') IS NOT NULL 
BEGIN
	DROP FUNCTION [hrg].combinedDayOrdNotNull17_18
END

GO

create function [hrg].combinedDayOrdNotNull17_18(@HRG varchar(10))
RETURNS bit
AS
BEGIN
	DECLARE @combNotNull bit;
	IF --HRG exists
		(
		SELECT COUNT(HRGCode)
		FROM hrg.[HRG_17/18]
		WHERE HRGCode = @HRG
		) = 0
		SET @combNotNull = NULL
	ELSE IF 
		(
		SELECT TOP 1 CombDayOrdElecTar 
		FROM hrg.[HRG_17/18]
		WHERE HRGCode = @HRG
		) IS NULL
		SET @combNotNull = 0
	ELSE 
		SET @combNotNull = 1;
	RETURN @combNotNull;
END


GO 

IF OBJECT_ID('hrg.combinedDayOrdNotNull18_19') IS NOT NULL 
BEGIN
	DROP FUNCTION [hrg].combinedDayOrdNotNull18_19
END

GO

create function [hrg].combinedDayOrdNotNull18_19(@HRG varchar(10))
RETURNS bit
AS
BEGIN
	DECLARE @combNotNull bit;
	IF --HRG exists
		(
		SELECT COUNT(HRGCode)
		FROM hrg.[HRG_18/19]
		WHERE HRGCode = @HRG
		) = 0
		SET @combNotNull = NULL
	ELSE IF 
		(
		SELECT TOP 1 CombDayOrdElecTar 
		FROM hrg.[HRG_18/19]
		WHERE HRGCode = @HRG
		) IS NULL
		SET @combNotNull = 0
	ELSE 
		SET @combNotNull = 1;
	RETURN @combNotNull;
END

GO

--Function: calculates number of days over the trim cut off point
--17/18
IF OBJECT_ID('hrg.daysOverTrim17_18') IS NOT NULL 
BEGIN
	DROP FUNCTION [hrg].daysOverTrim17_18
END

GO

create function [hrg].daysOverTrim17_18(@admissionType varchar(50), @HRG varchar(50), @epidur int)
RETURNS int
AS
BEGIN
	DECLARE @elecTrimPoint int;
	DECLARE @nonElecTrimPoint int;
	SET @elecTrimPoint = (SELECT OrdElecTrim FROM hrg.[HRG_17/18] WHERE HRGCode = @HRG);
	SET @nonElecTrimPoint = (SELECT NonElecTrim FROM hrg.[HRG_17/18] WHERE HRGCode = @HRG);
	RETURN
	CASE
		WHEN @admissionType = 'elective' and @epidur > @elecTrimPoint THEN 
				@epidur - @elecTrimPoint
		WHEN @admissionType = 'nonElective' and @epidur > @nonElecTrimPoint THEN 
				@epidur - @nonElecTrimPoint
		ELSE
			0
	END
END

GO

--18/19
IF OBJECT_ID('hrg.daysOverTrim18_19') IS NOT NULL 
BEGIN
	DROP FUNCTION [hrg].daysOverTrim18_19
END

GO

create function [hrg].daysOverTrim18_19(@admissionType varchar(50), @HRG varchar(50), @epidur int)
RETURNS int
AS
BEGIN
	DECLARE @elecTrimPoint int;
	DECLARE @nonElecTrimPoint int;
	SET @elecTrimPoint = (SELECT OrdElecTrim FROM hrg.[HRG_18/19] WHERE HRGCode = @HRG);
	SET @nonElecTrimPoint = (SELECT NonElecTrim FROM hrg.[HRG_18/19] WHERE HRGCode = @HRG);
	RETURN
	CASE
		WHEN @admissionType = 'elective' and @epidur > @elecTrimPoint THEN 
				@epidur - @elecTrimPoint
		WHEN @admissionType = 'nonElective' and @epidur > @nonElecTrimPoint THEN 
				@epidur - @nonElecTrimPoint
		ELSE
			0
	END
END

GO

--Calculates the tariff to add on if the number of days is over the trim cut off point
--17/18
IF OBJECT_ID('hrg.calculateTrimTariff17_18') IS NOT NULL 
BEGIN
	DROP FUNCTION [hrg].calculateTrimTariff17_18
END

GO

create function [hrg].calculateTrimTariff17_18(@admissionType varchar(50), @HRG varchar(50), @daysOverTrim int)
RETURNS money
AS
BEGIN
	RETURN
	CASE
		WHEN @admissionType = 'elective' THEN 
				@daysOverTrim * (SELECT PerDayLong FROM hrg.[HRG_17/18] WHERE HRGCode = @HRG) 
		WHEN @admissionType = 'nonElective' THEN 
				@daysOverTrim * (SELECT PerDayLong FROM hrg.[HRG_17/18] WHERE HRGCode = @HRG)
		ELSE
			0
	END
END

GO

--18/19
IF OBJECT_ID('hrg.calculateTrimTariff18_19') IS NOT NULL 
BEGIN
	DROP FUNCTION [hrg].calculateTrimTariff18_19
END

GO

create function [hrg].calculateTrimTariff18_19(@admissionType varchar(50), @HRG varchar(50), @daysOverTrim int)
RETURNS money
AS
BEGIN
	RETURN
	CASE
		WHEN @admissionType = 'elective' THEN 
				@daysOverTrim * (SELECT PerDayLong FROM hrg.[HRG_18/19] WHERE HRGCode = @HRG) 
		WHEN @admissionType = 'nonElective' THEN 
				@daysOverTrim * (SELECT PerDayLong FROM hrg.[HRG_18/19] WHERE HRGCode = @HRG)
		ELSE
			0
	END
END

GO

--Calculates final tariff using whether it is elective/non-elective, whether combined is available, number of days over trim point, 
--whether a non-elective case is under 2 days (reduced rate)

--17/18
IF OBJECT_ID('hrg.calculateFinalTariff17_18') IS NOT NULL 
BEGIN
	DROP FUNCTION [hrg].calculateFinalTariff17_18
END

GO

--Note: epidur must be an int so must convert epidur in the table
create function [hrg].calculateFinalTariff17_18(@HRG varchar(50), @epidur int, @admimeth varchar(50))
RETURNS money
AS 
BEGIN
	DECLARE @finalTariff money;
	DECLARE @admissionType varchar(50);
	SET @admissionType = [hrg].admissionType(@admimeth);
	DECLARE @trimTariff money;
	SET @trimTariff = [hrg].calculateTrimTariff17_18(@admissionType, @HRG, [hrg].daysOverTrim17_18(@admissionType, @HRG, @epidur));
	
	IF @admissionType = 'elective' 
	BEGIN
		SET @finalTariff =
			IIF([hrg].combinedDayOrdNotNull17_18(@HRG) = 1, 
									(SELECT CombDayOrdElecTar FROM hrg.[HRG_17/18] WHERE HRGCode = @HRG) + @trimTariff,
									(SELECT IIF(
										@epidur = 0, 
										(SELECT DayTar FROM hrg.[HRG_17/18] WHERE HRGCode = @HRG), --Could put these into clear variables
										(SELECT OrdElecTar FROM hrg.[HRG_17/18] WHERE HRGCode = @HRG) + @trimTariff
												)
									)
				);
	END
	ELSE IF @admissionType = 'nonElective'
	BEGIN
		DECLARE @reducedShortStay money = (SELECT ReducedShortEmTar FROM hrg.[HRG_17/18] WHERE HRGCode = @HRG);
		SET @finalTariff = 
			(SELECT CASE	
				WHEN @epidur < 2 and @reducedShortStay IS NOT NULL THEN @reducedShortStay
				ELSE 
					@trimTariff + (SELECT NonElecTar FROM hrg.[HRG_17/18] WHERE HRGCode = @HRG)
			END
			)
	END

	RETURN @finalTariff;
END

GO

--18/19
IF OBJECT_ID('hrg.calculateFinalTariff18_19') IS NOT NULL 
BEGIN
	DROP FUNCTION [hrg].calculateFinalTariff18_19
END

GO

--Note: epidur must be an int so must convert epidur in the table
create function [hrg].calculateFinalTariff18_19(@HRG varchar(50), @epidur int, @admimeth varchar(50))
RETURNS money
AS 
BEGIN
	DECLARE @finalTariff money;
	DECLARE @admissionType varchar(50);
	SET @admissionType = [hrg].admissionType(@admimeth);
	DECLARE @trimTariff money;
	SET @trimTariff = [hrg].calculateTrimTariff18_19(@admissionType, @HRG, [hrg].daysOverTrim18_19(@admissionType, @HRG, @epidur));
	
	IF @admissionType = 'elective' 
	BEGIN
		SET @finalTariff =
			IIF([hrg].combinedDayOrdNotNull18_19(@HRG) = 1, 
									(SELECT CombDayOrdElecTar FROM hrg.[HRG_18/19] WHERE HRGCode = @HRG) + @trimTariff,
									(SELECT IIF(
										@epidur = 0, 
										(SELECT DayTar FROM hrg.[HRG_18/19] WHERE HRGCode = @HRG), --Could put these into clear variables
										(SELECT OrdElecTar FROM hrg.[HRG_18/19] WHERE HRGCode = @HRG) + @trimTariff
												)
									)
				);
	END
	ELSE IF @admissionType = 'nonElective'
	BEGIN
		DECLARE @reducedShortStay money = (SELECT ReducedShortEmTar FROM hrg.[HRG_18/19] WHERE HRGCode = @HRG);
		SET @finalTariff = 
			(SELECT CASE	
				WHEN @epidur < 2 and @reducedShortStay IS NOT NULL THEN @reducedShortStay
				ELSE 
					@trimTariff + (SELECT NonElecTar FROM hrg.[HRG_18/19] WHERE HRGCode = @HRG)
			END
			)
	END

	RETURN @finalTariff;
END

GO

--Procedure to Calculate tariff and create new table with extra tariff column. This takes 2.5 mins to run so seems a bit long!?
--17/18
IF OBJECT_ID('create_Calculated_Tariffs_Table17_18') IS NOT NULL 
BEGIN
	DROP PROCEDURE create_Calculated_Tariffs_Table17_18
END

GO

CREATE PROC create_Calculated_Tariffs_Table17_18
AS
IF OBJECT_ID('[hrg].HRGHesCalculateTariff17_18') IS NOT NULL
BEGIN
	DROP TABLE HRGHesCalculateTariff17_18
END

SELECT *, hrg.calculateFinalTariff17_18(HRGCode, epidur, admimeth) AS Tariff
INTO hrg.HRGHesCalculateTariff17_18
FROM [hrg].[hesHRG]

GO

--18/19
IF OBJECT_ID('create_Calculated_Tariffs_Table18_19') IS NOT NULL 
BEGIN
	DROP PROCEDURE create_Calculated_Tariffs_Table18_19
END

GO

CREATE PROC create_Calculated_Tariffs_Table18_19
AS
IF OBJECT_ID('[hrg].HRGHesCalculateTariff18_19') IS NOT NULL
BEGIN
	DROP TABLE HRGHesCalculateTariff18_19
END

SELECT *, hrg.calculateFinalTariff18_19(HRGCode, epidur, admimeth) AS Tariff
INTO hrg.HRGHesCalculateTariff18_19
FROM [hrg].[hesHRG]

GO

--Execute procedures
exec create_Calculated_Tariffs_Table17_18

GO

exec create_Calculated_Tariffs_Table18_19

GO

--FINISHED!!!

----Tests----------------------
---------------------------
---------------------------
----All passed as of 22/02/2019
--SELECT hrg.calculateFinalTariff17_18('MA04D', 5, '22'); --Expected 1524
--SELECT hrg.calculateFinalTariff17_18('MA04D', 9, '22'); --Expected 2728


--SELECT hrg.calculateFinalTariff17_18('LB52A', 0, '12'); --2174
--SELECT hrg.calculateFinalTariff17_18('LB52A', 5, '12'); --2174
--SELECT hrg.calculateFinalTariff17_18('LB52A', 9, '13'); --2390 


--SELECT hrg.calculateFinalTariff17_18('LB51B', 0, '12'); --1181
--SELECT hrg.calculateFinalTariff17_18('LB51B', 1, '11'); --1067
--SELECT hrg.calculateFinalTariff17_18('LB51B', 5, '13'); --1067
--SELECT hrg.calculateFinalTariff17_18('LB51B', 6, '16'); --1283

----Check non-elec reduced rates
--SELECT hrg.calculateFinalTariff17_18('LB57C', 0, '22'); --754
--SELECT hrg.calculateFinalTariff17_18('LB57C', 1, '20'); --754


--SELECT hrg.calculateFinalTariff17_18('LB57C', 5, '23'); --2512
--SELECT hrg.calculateFinalTariff17_18('LB57C', 6, '12'); --2018 
--SELECT hrg.calculateFinalTariff17_18('LB51B', 0, '22'); --1135
--SELECT hrg.calculateFinalTariff17_18('LB51B', 1, '22'); --1135
--SELECT hrg.calculateFinalTariff17_18('LB51B', 2, '22'); --1135
--SELECT hrg.calculateFinalTariff17_18('LB51B', 5, '22'); --1135
--SELECT hrg.calculateFinalTariff17_18('LB51B', 9, '22'); --1999



----Working fine
--SELECT hrg.admissionType('11');--elective
--SELECT hrg.admissionType('12');--elective
--SELECT hrg.admissionType('13');--elective
--SELECT hrg.admissionType('21');--nonelective
--SELECT hrg.admissionType('22');--nonelective
--SELECT hrg.admissionType('23');--nonelective
--SELECT hrg.admissionType('31');--maternity

----Seems fine
--SELECT hrg.combinedDayOrdNotNull17_18('SA02J') --1
--SELECT hrg.combinedDayOrdNotNull17_18('PX07A') --1
--SELECT hrg.combinedDayOrdNotNull17_18('MA04D') --0
--SELECT hrg.combinedDayOrdNotNull17_18('LB51B') --0

----Seems fine
--SELECT hrg.daysOverTrim17_18('elective', 'MA02A', 0) --0
--SELECT hrg.daysOverTrim17_18('elective', 'MA02A', 15)--0 
--SELECT hrg.daysOverTrim17_18('elective', 'MA02A', 16) --0
--SELECT hrg.daysOverTrim17_18('elective', 'MA02A', 17) --1
--SELECT hrg.daysOverTrim17_18('elective', 'MA02A', 100)--84

--SELECT hrg.daysOverTrim17_18('nonElective', 'MA02A', 47)--0 
--SELECT hrg.daysOverTrim17_18('nonElective', 'MA02A', 48) --1
--SELECT hrg.daysOverTrim17_18('elective', 'LB52A', 9) --1


--SELECT hrg.calculateTrimTariff17_18('elective', 'LB52A', 1) --216
--SELECT hrg.calculateTrimTariff17_18('nonElective', 'MA02A', 1) --301


			

