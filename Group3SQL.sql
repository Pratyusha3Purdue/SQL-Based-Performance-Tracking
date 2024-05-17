
-- Q1 - latest month payment of CW 
select name, cur_month, round(ppw*tot_words) as total_pay from
(
SELECT employees.Name, monthname(updateddate) as cur_month,
 employees.Pricer_Per_Word as ppw,  sum(reports.WordCount) AS tot_words 
FROM reports 
join employees 
on employees.EmployeeID = reports.ContentWriterID
where month(updateddate) = month(curdate())-1
group by employees.Name, monthname(updateddate), employees.Pricer_Per_Word)a
order by 3 desc;

-- Q2 - Net monthly expenditure of company on CW's
select cur_month, sum(round(ppw*tot_words)) as total_pay from
(
SELECT employees.Name, monthname(WrittenDate) as cur_month, 
employees.Pricer_Per_Word as ppw,  sum(reports.WordCount) AS tot_words 
FROM reports 
join employees 
on employees.EmployeeID = reports.ContentWriterID
group by employees.Name, monthname(WrittenDate), employees.Pricer_Per_Word)a
group by cur_month;

-- Q3 Commision earned by cw in the latest month based on threshold
select employeeid, month1, 
case 
when 
c_l < (case when L_m_commission is null then 0 else L_m_commission end) then 0 
when 
cumulate_commission > c_l and c_l > (case when L_m_commission is null then 0 else L_m_commission end) 
		then c_l - (case when L_m_commission is null then 0 else L_m_commission end)
when 
c_l > (case when L_m_commission  is null then 0 else L_m_commission  end) 
		then cumulate_commission - (case when L_m_commission is null then 0 else L_m_commission end) 
        end as current_month_pay,
case when L_m_commission < c_l then L_m_commission
when L_m_commission is null then 0
when L_m_commission > c_l then c_l end
as commision_earned_until_last_month
        from(
select *, lag(cumulate_commission,1) over(partition by employeeid order by month1) as L_m_commission
from
(select * , sum(commision_earned) over(partition by employeeid order by month1) as cumulate_commission
from
(select employeeid, month1, commision_rate* lead_count as commision_earned, c_l from
(select employeeid, commision_rate, c_l , monthname(created_at) as month1, count(id) as lead_count
from
(select employeeid, reportid, commision_rate, commision_limit as c_l
from employees as a
join reports as b
on a.employeeid = b.contentwriterid
where title = 'Content Writer') as c
join leads as d
on c.reportid = d.report_id
where year(created_at) = 2023
group by employeeid, commision_rate, c_l, month1)e)f)g)h
where month1 = monthname(date_sub(curdate(), interval 1 month))
order by 4 desc;


-- Q4 Average days it takes to publish after approval
SELECT  AVG(DATEDIFF(updateddate, QC_date)) AS avg_days
FROM reports 

WHERE reports.ContentWriterID != 0 and QC_STATUS = 'Approved';

-- Q5 Best Marketing Analyst 
select d.employeeid, name, sum(leadcount) as leadcount from
(select c.EmployeeID, count(a.id) as leadcount
from leads as a
left join reports as b
on a.report_id = b.ReportID
left join domain as c
on c.DomainID = b.DomainID
where year(a.created_at) = year(current_date())
group by c.EmployeeID
having c.EmployeeID is not NULL)d
join 
employees e 
on d.employeeid = e.employeeid
where title = 'Analyst'
group by 1,2;

-- Q6 Within 90 days of publishing the report, what proportion of the articals published in a particular domain are generating leads
select distinct domain, article_proportion*100 as `article_proportion in %` from
(select  domainid, 
count(case when id is not null 
	and updateddate between date_sub(created_at, INTERVAL 90 DAY) and 
    created_at then report_id else null end)/count(report_id) as article_proportion   
from reports as a
left join 
leads b
on a.reportid = b.report_id
group by 1
)c
join 
domain d
on c.domainid = d.domainid
order by 2 desc;

-- Q7 content writer with zero leads in last quarter

select distinct name, count(id) as leads_cnt from
(select a.name, b.reportid, b.domainid from
 employees as a 
inner join 
reports as b
on a.employeeid = b.contentwriterid
where title = 'Content Writer') as c
left join 
(select * from leads where created_at between date_sub(CURDATE(), INTERVAL 90 DAY) AND CURDATE())d
on c.reportid = d.report_id
group by 1
having leads_cnt = 0;


-- Q8 Percentage change in Marketing Analyst Performance Month-over-month (leads generated in M-1 vs leads generated in M-2)
SELECT a.employeeid, 
       ((m2_leadcount - m1_leadcount) * 100 / m1_leadcount) AS percent_lead_change 
FROM (
    SELECT c.EmployeeID, 
           COUNT(CASE WHEN MONTH(CURDATE()) - MONTH(created_at) = 1 
           THEN a.id ELSE NULL END) AS m1_leadcount, 
           COUNT(CASE WHEN MONTH(CURDATE()) - MONTH(created_at) = 2 
           THEN a.id ELSE NULL END) AS m2_leadcount 
    FROM leads AS a
    LEFT JOIN reports AS b ON a.report_id = b.ReportID
    LEFT JOIN domain AS c ON c.DomainID = b.DomainID
    WHERE YEAR(a.created_at) = YEAR(CURDATE()) 
    AND c.employeeid IN (SELECT DISTINCT employeeid FROM employees WHERE title = "Analyst")
    GROUP BY c.EmployeeID
) AS a
WHERE a.employeeid IS NOT NULL
order by 2 desc;

-- which domain is creating more leads
select domain.Domain, count(leads.id) as leadcount
from leads
left join reports
on leads.report_id = reports.ReportID
left join domain
on domain.DomainID = reports.DomainID
GROUP by domain
order by leadcount DESC;

 
-- Number of leads generated in previous month
select count(*)

from leads
where month(created_at) = month(now())-1;

--  Which region is creating more leads?
select region.Continent, count(leads.id)
from leads
left join region
on leads.country = region.Country
group by Continent
having region.Continent is not NULL;

-- Q10 marketing team members performance till date per month
select domain.EmployeeID, month(leads.created_at) as leadmonth, count(leads.id) as leadcount
from leads
left join reports
on leads.report_id = reports.ReportID
left join domain
on domain.DomainID = reports.DomainID
where year(leads.created_at) = year(current_date()) and 
employeeid in (select employeeid from employees where title = 'Analyst')
group by month(leads.created_at), domain.EmployeeID
having domain.EmployeeID is not NULL;

