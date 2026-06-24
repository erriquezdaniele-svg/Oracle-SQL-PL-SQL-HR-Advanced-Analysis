-- Oracle SQL Advanced Analytics Project

-- [QUERY 01] - ANALISI EVOLUTIVA DELLA SPESA SALARIALE PER DECENNIO E DIPARTIMENTO
-- Scopo: Analizzare come la spesa degli stipendi si è evoluta nel tempo, 
-- evidenziando i periodi di maggiore crescita aziendale.

WITH dati_base AS (
    SELECT
        nvl(d.department_name, 'Senza Dipartimento')    AS nome_dipartimento,
        floor(extract(YEAR FROM e.hire_date) / 10) * 10 AS decennio,
        e.salary                                        AS salario
    FROM
        employees   e
        LEFT JOIN departments d ON ( e.department_id = d.department_id )
)
SELECT
    *
FROM
    dati_base PIVOT (
        SUM(salario)
        FOR decennio
        IN ( 1980 AS anni_80, 1990 AS anni_90, 2000 AS anni_00 )
    )
ORDER BY
    nome_dipartimento;

-- [query 02] - analisi comparativa dei costi e posizionamento salariale
-- scopo: classificare i dipendenti in base al loro impatto economico rispetto alla media 
-- dipartimentale e aziendale utilizzando una inline view per l'efficienza.

SELECT
    concat(e.first_name || ' ', e.last_name) nome_cognome,
    d.department_name,
    e.salary,
    round(x.media_aziendale, 2)              media_aziendale,
    CASE
        WHEN e.salary > x.media_dept
             AND e.salary > x.media_aziendale THEN
            'alto'
        WHEN e.salary < x.media_dept
             AND e.salary > x.media_aziendale THEN
            'medio'
        ELSE
            'basso'
    END                                      livello_costo,
    round(e.salary - x.media_dept, 2)        differenza_stipendio
FROM
    employees   e
    LEFT OUTER JOIN departments d ON ( e.department_id = d.department_id )
    JOIN (
        SELECT
            department_id,
            AVG(salary)
            OVER(PARTITION BY department_id) AS media_dept,
            AVG(salary)
            OVER()                           AS media_aziendale
        FROM
            employees
    )           x ON ( nvl(e.department_id, -1) = nvl(x.department_id, -1) )
WHERE
    e.manager_id IS NOT NULL
GROUP BY
    e.first_name,
    e.last_name,
    d.department_name,
    e.salary,
    x.media_dept,
    x.media_aziendale
ORDER BY
    e.salary DESC;            

-- [query 03] - ricostruzione gerarchica dell'organigramma (hierarchical query)
-- scopo: visualizzare l'intera catena aziendale partendo dai vertici.

SELECT
    level                                   AS grado_gerarchico,
    lpad(' ', 3 *(level - 1))
    || e.first_name
    || ' '
    || e.last_name                          AS dipendente_indentato,
    e.job_id,
    PRIOR e.first_name
    || ' '
    || PRIOR e.last_name                    AS responsabile_diretto,
    sys_connect_by_path(e.last_name, ' > ') AS percorso_carriera
FROM
    employees e
CONNECT BY
    PRIOR e.employee_id = e.manager_id
START WITH e.manager_id IS NULL
ORDER SIBLINGS BY
    e.last_name;

-- [query 04] - analisi comparativa e ranking salariale (window functions)
-- scopo: calcolare pesi percentuali e classifiche interne ai dipartimenti.

SELECT
    d.department_name,
    e.first_name
    || ' '
    || e.last_name AS nominativo,
    e.salary       AS stipendio,
    RANK()
    OVER(PARTITION BY e.department_id
         ORDER BY
             e.salary DESC
    )              AS posizione_reparto,
    round(AVG(e.salary)
          OVER(PARTITION BY e.department_id),
          2)       AS media_reparto,
    round((e.salary / SUM(e.salary)
                      OVER(PARTITION BY e.department_id)) * 100,
          2)       AS incidenza_percentuale,
    LEAD(e.salary)
    OVER(PARTITION BY e.department_id
         ORDER BY
             e.salary DESC
    )              AS stipendio_successivo
FROM
         employees e
    JOIN departments d ON ( e.department_id = d.department_id )
ORDER BY
    d.department_name,
    posizione_reparto;

-- [query 05] - data quality, filtering avanzato (exists) e campionamento (rownum)
-- scopo: individuare i dipendenti che non hanno un dipartimento valido (not exists)
-- o quelli che appartengono a dipartimenti attivi (exists), pulendo i dati 
-- e limitando il risultato per campionamento..

SELECT
    rpad(
        upper(e.last_name),
        15,
        '*'
    )                           AS cognome_formattato,
    lower(e.email || '@hr.com') AS email_bonificata,
    nvl(
        to_char(e.commission_pct, '0.99'),
        'nessuna provvigione'
    )                           AS info_commissione,
    e.salary
FROM
    employees e
WHERE
    EXISTS (
        SELECT
            1
        FROM
            departments d
        WHERE
            d.department_id = e.department_id
    )
    AND e.salary > (
        SELECT
            AVG(salary)
        FROM
            employees
    )
    AND ROWNUM <= 10
ORDER BY
    e.salary DESC;