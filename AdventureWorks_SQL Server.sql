use AdventureWorks2019;

-- 1.find the percentage of married/unmarried employees

select MaritalStatus,Gender,count(*) as "count",
concat(round(100*cast(count(*) as float)/(select count(*) from HumanResources.Employee),2),' %') as percentage
from HumanResources.Employee he
group by MaritalStatus,Gender;

--#(we have to convert one of the values into floating number, othervise division result ---will be int, as both values are represented as int in the dataset)

-- 2.calculate average age of married/unmarried male/female employees

with t1 as 
(select BusinessEntityID,MaritalStatus,Gender,DATEDIFF(dd,BirthDate,HireDate)/365.0 as age
from HumanResources.Employee)
select MaritalStatus,Gender,avg(age) as AVGAge
from t1
group by MaritalStatus,Gender
order by MaritalStatus,Gender;
--#(we can’t subtract one date from another to find difference in days between the two, --like in MySQL. We use datediff and specify first argument(‘dd’ in this case))


-- 3.Create a column for job categories. 
-- Which Category has highest avg employee age? lowest? 
-- Find avg 

with t1 as
(select BusinessEntityID, datediff(DAY,BirthDate,HireDate)/365.0 as Age,
case
when JobTitle like '%manager%' then 'Manager'
when JobTitle like '%engineer%' then 'Engineer'
when JobTitle like '%specialist%' then 'Specialist'
when JobTitle like '%technician%' then 'Technician'
when JobTitle like '%representative%' then 'Representative'
else 'Other'
end as JobCategory
from HumanResources.Employee)
select JobCategory, count(JobCategory) as NumberOfEmployees, avg(Age) as AVGAge
from t1
group by JobCategory
order by NumberOfEmployees asc;

-- #Representatives cateogory has highest avg employee age,while specialist category has the lowest.


-- 4.Find information about Georgian emplyees

select pp.BusinessEntityID,FirstName,LastName,NationalIDNumber,JobTitle,BirthDate,HireDate,MaritalStatus,Gender,VacationHours,SickLeaveHours
from Person.Person pp
join HumanResources.Employee he on pp.BusinessEntityID=he.BusinessEntityID
where LastName like '%shvili' or LastName like 'dze';


--5.find which countries had the biggest share of total monthly sales for each month of each year.
-- what was the percentage.
with t1 as 
(select year(orderdate) as year, datename(month,orderdate) as month,TerritoryID,sum(totaldue) as amount
from sales.SalesOrderHeader
group by year(orderdate), datename(month,orderdate),TerritoryID)
,t2 as 
(select year,month,sum(amount) as monthlyamount
from t1
group by year,month)
,t3 as
(select t1.year,t1.month,TerritoryID,amount,monthlyamount, round(amount/monthlyamount*100,2) as per
from t1
join t2 on t2.year=t1.year and t2.month=t1.month)  --In SQL Server you can use CTEs to  join tables
,t4 as
(select t3.*, ROW_NUMBER() over(partition by year,month order by year,month,per desc) as rn
from t3)
select year,month,concat(name,' ',CountryRegionCode) as country,amount,monthlyamount as 'monthly_amount',concat(per,' %') as 'percent_of_monthly_ordervalue'
from t4
join sales.SalesTerritory st on t4.TerritoryID=st.TerritoryID
where rn=1;

--6.For each order show the SalesOrderID and SubTotal calculated three ways:
--A) From the SalesOrderHeader
--B) Sum of OrderQty*UnitPrice
--Find orders that have difference values of sales accoring to both calculation methods
with t1 as
(select soh.SalesOrderID, sum(subtotal) as subtotalV1, sum(orderQty*UnitPrice) as subtotalV2,
iif( abs(sum(subtotal)-sum(orderQty*UnitPrice))>10,'Yes','No') as 'Difference'
from Sales.SalesOrderHeader soh
join sales.SalesOrderDetail sod
on soh.SalesOrderID=sod.SalesOrderID
group by soh.SalesOrderID)
select distinct t1.SalesOrderID, subtotalV1,subtotalV2,Difference
from t1
join sales.SalesOrderDetail sod on t1.SalesOrderID=sod.SalesOrderID
where sod.SalesOrderID in (select SalesOrderID from t1 where t1.Difference='Yes')
order by t1.SalesOrderID;

--7.Find 10 highest selling products by value

with t1 as
(select ProductID,sum(OrderQty*UnitPrice) as value
from Sales.SalesOrderDetail sod
group by ProductID)
select top 10 t1.ProductID,Name, format(value,'C2') as value
from t1
join Production.Product pp on t1.ProductID=pp.ProductID
order by t1.value desc;


--8.Show how many orders are in the following ranges (in $):
--RANGE      Num Orders      Total Value
--0-  99
--100- 999
--1000-9999
--10000-

with t1 as 
(select SalesOrderID,sum(OrderQty*UnitPrice) as value
from Sales.SalesOrderDetail
group by SalesOrderID)
,t2 as
(select t1.*, 
case 
when t1.value between 0 and 99 then '0-99'
when t1.value between 100 and 999 then '100-999'
when t1.value between 1000 and 9999 then '1000-9999'
else '10000-'
end as category
from t1)
select category, count(category) as count_of_category
from t2
group by category;


--9.Identify the three most important regions

with t1 as
(select TerritoryID,sum(SubTotal) as sum_of_subtotal
from Sales.SalesOrderHeader
group by TerritoryID)
,t2 as
(select t1.*,concat(Name,' ',CountryRegionCode) as region,ROW_NUMBER() over(order by sum_of_subtotal desc) as rn  -- This way you can order table by c
from t1
join Sales.SalesTerritory st on t1.TerritoryID=st.TerritoryID)
select region,FORMAT(sum_of_subtotal,'c2') as sum_of_subtotal_f
from t2
order by sum_of_subtotal desc;



