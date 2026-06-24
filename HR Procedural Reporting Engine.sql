-- =============================================================================
--  HR PROCEDURAL REPORTING ENGINE
--  Report analitico del personale per dipartimento.
--  Architettura: funzioni di calcolo + procedure di orchestrazione + cursori espliciti.
-- =============================================================================

SET SERVEROUTPUT ON;

DECLARE
    FUNCTION calcola_anzianita (
        p_hire_date IN employees.hire_date%TYPE
    ) RETURN NUMBER IS
    BEGIN
        RETURN trunc(months_between(sysdate, p_hire_date) / 12,
                     1);
    END;

    FUNCTION scarto_reparto_azienda (
        p_department_id departments.department_id%TYPE
    ) RETURN NUMBER IS
        v_media_aziendale    NUMBER(10, 2);
        v_media_dipartimento NUMBER(10, 2);
    BEGIN
        SELECT
            AVG(salary)
        INTO v_media_aziendale
        FROM
            employees;

        SELECT
            AVG(salary)
        INTO v_media_dipartimento
        FROM
            employees
        WHERE
            department_id = p_department_id;

        IF v_media_dipartimento IS NULL THEN
            v_media_dipartimento := 0;
        END IF;
        RETURN round(v_media_aziendale - v_media_dipartimento, 2);
    END;

    FUNCTION classifica_stipendio (
        p_salary employees.salary%TYPE
    ) RETURN VARCHAR2 IS
    BEGIN
        CASE
            WHEN p_salary < 3000 THEN
                RETURN 'Basso';
            WHEN
                p_salary >= 3000
                AND p_salary < 7000
            THEN
                RETURN 'Medio';
            WHEN
                p_salary >= 7000
                AND p_salary < 14000
            THEN
                RETURN 'Medio-alto';
            ELSE
                RETURN 'Alto';
        END CASE;
    END;

    PROCEDURE stampa_dipendenti_dipartimento (
        p_department_id departments.department_id%TYPE
    ) IS

        CURSOR c_dipendenti IS
        SELECT
            e.employee_id,
            e.first_name,
            e.last_name,
            e.salary,
            e.hire_date
        FROM
            employees e
        WHERE
            e.department_id = p_department_id
        ORDER BY
            e.employee_id;

        v_id         employees.employee_id%TYPE;
        v_nome       employees.first_name%TYPE;
        v_cognome    employees.last_name%TYPE;
        v_salario    employees.salary%TYPE;
        v_hire_date  employees.hire_date%TYPE;
        v_classifica VARCHAR2(20);
        v_anzianita  NUMBER;
        c_linea      CONSTANT VARCHAR2(110) := '    ----------------------------------------------------------------------------------------------------------'
        ;
    BEGIN
        OPEN c_dipendenti;
        dbms_output.put_line(c_linea);
        dbms_output.put_line('    '
                             || rpad('ID', 8, ' ')
                             || '| '
                             || rpad('NOME', 15, ' ')
                             || '| '
                             || rpad('COGNOME', 20, ' ')
                             || '| '
                             || lpad('SALARIO', 12, ' ')
                             || '| '
                             || rpad('FASCIA', 15, ' ')
                             || '| '
                             || lpad('ANZIANITA', 12, ' '));

        dbms_output.put_line(c_linea);
        LOOP
            FETCH c_dipendenti INTO
                v_id,
                v_nome,
                v_cognome,
                v_salario,
                v_hire_date;
            EXIT WHEN c_dipendenti%notfound;
            v_classifica := classifica_stipendio(v_salario);
            v_anzianita := calcola_anzianita(v_hire_date);
            dbms_output.put_line('    '
                                 || rpad(v_id, 8, ' ')
                                 || '| '
                                 || rpad(v_nome, 15, ' ')
                                 || '| '
                                 || rpad(v_cognome, 20, ' ')
                                 || '| '
                                 || lpad(v_salario || ' €', 12, ' ')
                                 || '| '
                                 || rpad(v_classifica, 15, ' ')
                                 || '| '
                                 || lpad(v_anzianita || ' Anni', 12, ' '));

        END LOOP;

        CLOSE c_dipendenti;
        dbms_output.put_line(c_linea);
    END;

    PROCEDURE stampa_risorse IS

        CURSOR c_dipartimenti IS
        SELECT
            department_id,
            department_name
        FROM
            departments
        ORDER BY
            department_name;

        v_dept_id   departments.department_id%TYPE;
        v_dept_name departments.department_name%TYPE;
        v_scarto    NUMBER;
    BEGIN
        OPEN c_dipartimenti;
        LOOP
            FETCH c_dipartimenti INTO
                v_dept_id,
                v_dept_name;
            EXIT WHEN c_dipartimenti%notfound;
            v_scarto := scarto_reparto_azienda(v_dept_id);
            dbms_output.put_line(chr(10));
            dbms_output.put_line('=============================================================================================================='
            );
            dbms_output.put_line('DIPARTIMENTO: '
                                 || upper(v_dept_name)
                                 || ' (ID: '
                                 || v_dept_id
                                 || ') | Scarto Media Aziendale: '
                                 || v_scarto
                                 || ' €');

            dbms_output.put_line('=============================================================================================================='
            );
            stampa_dipendenti_dipartimento(v_dept_id);
        END LOOP;

        CLOSE c_dipartimenti;
    EXCEPTION
        WHEN OTHERS THEN
            IF c_dipartimenti%isopen THEN
                CLOSE c_dipartimenti;
            END IF;
            dbms_output.put_line('Errore: ' || sqlerrm);
    END;

BEGIN
    stampa_risorse();
END;
/