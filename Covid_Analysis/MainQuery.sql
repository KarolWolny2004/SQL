/*
Skills used: Aggregate Functions, Windows Functions, CTE's, Joins, Nested Query, Temp Tables, Creating Views, Converting Data Format


The following file is a project in which I analyze the history of COVID-19 in various countries around the world from 2020 to 2024. 
Because this is a portfolio project, I will strive to use as many different types of SQL syntax as possible. 
Creating this project was inspired by the movie: https://www.youtube.com/watch?v=qfyynHBFOsM&ab_channel=AlexTheAnalyst 
The project is not a copy of the one shown in the video. My queries differ from those shown in the video.

The data used in the project is from the website: https://ourworldindata.org/covid-deaths
*/




--Changing the format of certain variables
--select *
--from dbo.CovidDeaths
--exec sp_help 'dbo.CovidDeaths';
--alter table dbo.CovidDeaths
--alter column total_cases float
----alter column total_deaths float

--Presentation of data
SELECT *
FROM CovidDeaths;

--Selection of variables analysed
SELECT location, date, population, new_cases, total_cases, total_deaths
FROM CovidDeaths
ORDER BY location, date;

--Creation the infection rate  
SELECT location, date, (total_cases/population)*100 AS InfectionRate
FROM CovidDeaths
ORDER BY location, date;

--Ranking of countries with the highest incidence rate (proportion of the population that has ever contracted the virus)
SELECT TOP 10 location, MAX((total_cases/population)*100) AS InfectionRate
FROM CovidDeaths
GROUP BY location
HAVING MAX((total_cases/population)*100) IS NOT NULL
ORDER BY InfectionRate DESC;

--Average of current infection rates for continents 
SELECT continent, AVG(InfectionRate) AS AVGInfectionRate
FROM (
	SELECT continent, location, MAX((total_cases/population)*100) AS InfectionRate
	FROM CovidDeaths
	WHERE continent IS NOT NULL
	GROUP BY continent, location) AS MaxInfection
GROUP BY continent
ORDER BY AVGInfectionRate DESC;

--Actual COVID-19 mortality rate for the country (total deaths/total infections)
SELECT continent, location, date, MAX(total_cases) CurrentCases, MAX(total_deaths) AS CurrentDeaths
FROM CovidDeaths
GROUP BY continent, location

--Combined mortality rate with other averaged indicators
SELECT cd.continent, cd.location, MAX(cd.total_cases) CurrentCases, MAX(cd.total_deaths) AS CurrentDeaths,
	ROUND(AVG(cv.human_development_index),2) AS HumanDevelopmentIndex , 
	ROUND(AVG(cv.gdp_per_capita),2) AS GdpPerCapita, 
	ROUND(AVG(cv.life_expectancy),2) LifeExpectancy
FROM CovidDeaths as cd 
INNER JOIN CovidVaccinations as cv
	ON cd.location = cv.location
	AND cd.date = cv.date
WHERE cd.continent IS NOT NULL
GROUP BY cd.continent, cd.location
ORDER BY cd.continent, cd.location ;

--The difference between the average infection rate in a country and the average for the continent in which that country is located. 
--A ranking is created which ranks the countries of a continent in terms of this indicator. 
--The higher the ranking, the higher the average incidence for a country was in relation to the average incidence for the continent.

WITH AvgDiffrences 
AS ( 
SELECT continent, location,
	ROUND(AVG(InfectionRate) OVER(PARTITION BY location ),2) AS AvgLocationIR,
	ROUND(AVG(InfectionRate) OVER(PARTITION BY continent),2) AS AvgContinentIR
FROM (
	SELECT continent, location, MAX((total_cases/population)*100) AS InfectionRate
	FROM CovidDeaths
	WHERE continent IS NOT NULL
	GROUP BY continent, location) AS MaxInfection
)
SELECT Continent, Location, AvgLocationIR, AvgContinentIR, 
	ROUND((AvgLocationIR - AvgContinentIR),2) AS AvgDifferencePerCountry,
	DENSE_RANK() OVER(PARTITION BY continent ORDER BY (AvgLocationIR - AvgContinentIR) DESC ) AS Ranking
FROM AvgDiffrences
WHERE (AvgLocationIR - AvgContinentIR) IS NOT NULL
ORDER BY  continent, Ranking;

----------------------------------

--Using Temp Tables for the previous query
DROP TABLE IF EXISTS #StatisticsOfInfectionRates
CREATE TABLE #StatisticsOfInfectionRates 
(
Continent nvarchar(255),
Location nvarchar(255),
AvgIRbyLocation float,
AvgIRbyContinent float,
LocationContinentDifference numeric,
ContinentalRanking numeric
)

INSERT INTO #StatisticsOfInfectionRates
SELECT Continent, Location, AvgLocationIR, AvgContinentIR, 
	ROUND((AvgLocationIR - AvgContinentIR),2) AS AvgDifferencePerCountry,
	DENSE_RANK() OVER(PARTITION BY continent ORDER BY (AvgLocationIR - AvgContinentIR) DESC ) AS Ranking
FROM (
	SELECT continent, location,
		ROUND(AVG(InfectionRate) OVER(PARTITION BY location ),2) AS AvgLocationIR,
		ROUND(AVG(InfectionRate) OVER(PARTITION BY continent),2) AS AvgContinentIR
	FROM (
			SELECT continent, location, MAX((total_cases/population)*100) AS InfectionRate
			FROM CovidDeaths
			WHERE continent IS NOT NULL
			GROUP BY continent, location
		 ) AS MaxInfection
	 ) AS AvgDiffrences 
WHERE (AvgLocationIR - AvgContinentIR) IS NOT NULL
ORDER BY  continent, Ranking;

SELECT *
FROM #StatisticsOfInfectionRates

--Creating View for visualizations
GO
CREATE VIEW StatisticsOfInfectionRates AS
SELECT Continent, Location, AvgLocationIR, AvgContinentIR, 
	ROUND((AvgLocationIR - AvgContinentIR),2) AS AvgDifferencePerCountry,
	DENSE_RANK() OVER(PARTITION BY continent ORDER BY (AvgLocationIR - AvgContinentIR) DESC ) AS Ranking
FROM (
	SELECT continent, location,
		ROUND(AVG(InfectionRate) OVER(PARTITION BY location ),2) AS AvgLocationIR,
		ROUND(AVG(InfectionRate) OVER(PARTITION BY continent),2) AS AvgContinentIR
	FROM (
			SELECT continent, location, MAX((total_cases/population)*100) AS InfectionRate
			FROM CovidDeaths
			WHERE continent IS NOT NULL
			GROUP BY continent, location
		 ) AS MaxInfection
	 ) AS AvgDiffrences 
WHERE (AvgLocationIR - AvgContinentIR) IS NOT NULL;
GO

select *
from StatisticsOfInfectionRates