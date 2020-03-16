select * from OSOBY;

select * from wycieczki;

select * from REZERWACJE;
--3.a/
CREATE or replace VIEW RezerwacjeWszystkie
 AS
    SELECT
        w.ID_WYCIECZKI,
        w.NAZWA,
        w.KRAJ,
        w.DATA,
        o.IMIE,
        o.NAZWISKO,
        r.STATUS
    FROM WYCIECZKI w
    JOIN REZERWACJE r ON w.ID_WYCIECZKI = r.ID_WYCIECZKI
    JOIN OSOBY o ON r.ID_OSOBY = o.ID_OSOBY;

select * from REZERWACJEWSZYSTKIE;
--3.b/
CREATE OR REPLACE VIEW RezerwacjePotwierdzone
    AS
        SELECT *
        FROM REZERWACJEWSZYSTKIE r
        WHERE r.STATUS = 'P' or r.STATUS = 'Z';

select * from REZERWACJEPOTWIERDZONE;
--3.c/
CREATE View RezerwacjeWPrzyszlosci
    AS
        SELECT *
        FROM REZERWACJEWSZYSTKIE
        WHERE rezerwacjewszystkie.DATA > sysdate;

select * from RezerwacjeWPrzyszlosci;
--3.d/
CREATE OR REPLACE View WycieczkiMiejsca
    AS
        SELECT
               w.ID_WYCIECZKI,
               w.Kraj,
               w.data,
               w.nazwa,
               w.LICZBA_MIEJSC,
               w.LICZBA_MIEJSC - count(r.NR_REZERWACJI) as wolne_miejsca
        FROM WYCIECZKI w
        JOIN REZERWACJE r on w.ID_WYCIECZKI = r.ID_WYCIECZKI
        JOIN OSOBY o on r.ID_OSOBY = o.ID_OSOBY
        WHERE R.STATUS != 'A'
        GROUP BY w.ID_WYCIECZKI,w.Kraj, w.data, w.nazwa, w.LICZBA_MIEJSC;

select * from WycieczkiMiejsca;
--3.e/
CREATE or replace  View WycieczkiDostepne
    AS
        SELECT * FROM WycieczkiMiejsca
        WHERE wolne_miejsca>0
        and data > sysdate;
select * from WYCIECZKIDOSTEPNE
--4.a/UczestnicyWycieczki (id_wycieczki), procedura ma zwracać podobny zestaw danych jakwidok RezerwacjeWszystkie
CREATE OR REPLACE TYPE funkcja_a_wiersz AS object (
  kraj            VARCHAR(50),
  "data"          DATE,
  nazwa_wycieczki VARCHAR(100),
  imie            VARCHAR2(50),
  nazwisko        VARCHAR2(50),
  status          CHAR(1)
);


CREATE OR REPLACE TYPE funkcja_a_tablica IS TABLE OF funkcja_a_wiersz;

CREATE OR REPLACE
FUNCTION uczestnicywycieczki(id INT)
  return funkcja_a_tablica as v_ret funkcja_a_tablica;
  czy_jest                          integer;
  BEGIN
    SELECT COUNT(*) INTO czy_jest FROM WYCIECZKI WHERE WYCIECZKI.ID_WYCIECZKI = id;

    IF czy_jest = 0 THEN
      raise_application_error(-20004, 'Nie ma takiej wycieczki');
    END IF;

    SELECT funkcja_a_wiersz(r.KRAJ, r.DATA, r.NAZWA, r.IMIE,
                             r.NAZWISKO, r.STATUS)
        BULK COLLECT INTO v_ret
    FROM REZERWACJEWSZYSTKIE r
    WHERE r.ID_WYCIECZKI = id
    AND (r.STATUS != 'N');
    return v_ret;
  end uczestnicywycieczki;

  select uczestnicywycieczki(24) from dual;
--4.b/RezerwacjeOsoby(id_osoby), procedura ma zwracać podobny zestaw danych jak widok wycieczki_osoby

CREATE OR REPLACE
FUNCTION rezerwacjeosoby(id INT)
  return funkcja_a_tablica as v_ret funkcja_a_tablica;
  czy_jest                         integer;
  BEGIN
    SELECT COUNT(*) INTO czy_jest FROM OSOBY WHERE osoby.ID_OSOBY = id;

    IF czy_jest = 0 THEN
      raise_application_error(-20004, 'Nie ma takiej osoby');
    END IF;

    SELECT funkcja_a_wiersz(w.KRAJ, w.DATA, w.NAZWA, o.IMIE,
                             o.NAZWISKO, r.STATUS)
        BULK COLLECT INTO v_ret
    FROM WYCIECZKI w
           JOIN REZERWACJE r ON w.ID_WYCIECZKI = r.ID_WYCIECZKI
           JOIN OSOBY o ON r.ID_OSOBY = o.ID_OSOBY
    WHERE o.ID_OSOBY = id;
    return v_ret;
  end rezerwacjeosoby;

--4.c/DostepneWycieczki(kraj, data_od, data_do)
CREATE OR REPLACE TYPE funkcja_c_wiersz AS object (
  kraj            VARCHAR(50),
  "data"          DATE,
  nazwa_wycieczki VARCHAR(100),
  liczba_miejsc number,
  wolne_miejsca number
);

CREATE OR REPLACE TYPE funkcja_c_tablica IS TABLE OF funkcja_c_wiersz;


CREATE OR REPLACE
FUNCTION dostepnewycieczki(par_kraj    WYCIECZKI.KRAJ%TYPE, data_od DATE,
                            data_do DATE)
  return funkcja_c_tablica as v_ret funkcja_c_tablica;
  BEGIN
    IF data_do < data_od
    THEN
      raise_application_error(-20003, 'Nieprawidłowy przedział dat');
    END IF;

    SELECT funkcja_c_wiersz(w.kraj, w.data, w.nazwa, w.LICZBA_MIEJSC, w.wolne_miejsca)
        BULK COLLECT INTO v_ret
    FROM WycieczkiDostepne w
    WHERE w.KRAJ = par_kraj
      AND w.DATA >= data_od
      AND w.DATA <= data_do;
    return v_ret;
  end dostepnewycieczki;

    select * from WycieczkiDostepne;

  select dostepnewycieczki('Szczurolandia', '2020-04-01','2020-05-05') from dual;

--5.a/DodajRezerwacje(id_wycieczki, id_osoby), procedura powinna kontrolować czy wycieczka jeszcze się nie odbyła, i czy sa wolne miejsca

create or replace procedure DodajRezerwacja(par_id_wycieczki integer, par_id_osoby integer)
as
    jest integer;

    begin
        select count(*) into jest
        from OSOBY where ID_OSOBY = par_id_osoby;
        if jest = 0 then
            raise_application_error(-20000, 'Nie ma takiej osoby');
        end if;

        select count(*) into jest
        from WYCIECZKI where ID_WYCIECZKI = par_id_wycieczki;
        if jest = 0 then
            raise_application_error(-20004, 'Nie ma takiej wycieczki');
        end if;

        select sum(wolne_miejsca) into jest from (SELECT w.LICZBA_MIEJSC - count(r.NR_REZERWACJI)  as wolne_miejsca
            FROM WYCIECZKI w
            JOIN REZERWACJE r on w.ID_WYCIECZKI = r.ID_WYCIECZKI
            where w.ID_WYCIECZKI = par_id_wycieczki
            and r.STATUS != 'A'
            GROUP by w.LICZBA_MIEJSC);

        if jest - 1 < 0 then
             raise_application_error(-20006, 'Brak wolnych miejsc na tę wycieczkę');
        end if;

        select count(*) into jest
        from rezerwacje r
        where r.ID_WYCIECZKI = par_id_wycieczki
        and r.ID_OSOBY = par_id_osoby;
        if jest > 0
        then
            raise_application_error(-20007, 'Rezerwacja juz jest zrobiona');
        end if;

       insert into REZERWACJE (id_wycieczki, id_osoby, STATUS)
       values (par_id_wycieczki, par_id_osoby, 'N');
    end;

    select * from WYCIECZKI;
select * from OSOBY;
select * from WYCIECZKIDOSTEPNE;
begin dodajrezerwacja(27,21);
end;
select * from REZERWACJE;
begin ZMIENSTATUSREZERWACJI(4,'A');
end;

begin dodajrezerwacja(25,21);
end;

begin dodajrezerwacja(25,21);
end;

select * from WYCIECZKIDOSTEPNE;
select * from WYCIECZKIDOSTEPNE_2;

--5.b/ZmienStatusRezerwacji(nr_rezerwacji, status), procedura kontrolować czy możliwa jest zmiana statusu
create or replace procedure ZmienStatusRezerwacji(id_rezerwacji REZERWACJE.NR_REZERWACJI%TYPE,
                            nowy_status   REZERWACJE.STATUS%TYPE)
as
    jest integer;
    stary_status REZERWACJE.STATUS%TYPE;
    begin
        select count(*) into jest
        from REZERWACJE where REZERWACJE.NR_REZERWACJI = id_rezerwacji;
        if jest = 0 then
            raise_application_error(-20004, 'Nie ma takiej rezerwacji');
        end if;


    SELECT status INTO stary_status
    FROM REZERWACJE
    WHERE NR_REZERWACJI = id_rezerwacji;

    CASE

      WHEN nowy_status = 'N'
      THEN
        raise_application_error(-20103,
                                'Istniejąca rezerwacja nie może stać się nowa');

      WHEN stary_status = 'A'
      THEN
        SELECT COUNT(*) INTO jest
        FROM WycieczkiDostepne wd
               JOIN REZERWACJE r ON r.ID_WYCIECZKI = wd.ID_WYCIECZKI
        WHERE r.NR_REZERWACJI = id_rezerwacji;

        IF jest = 0
        THEN
          raise_application_error(-20101,
                                  'Brak miejsc dla przywrócenia anulowanej rezerwacji');
        END IF;
    ELSE null;
    END CASE;

    UPDATE REZERWACJE
    SET STATUS = nowy_status
    WHERE NR_REZERWACJI = id_rezerwacji;

    end ZmienStatusRezerwacji;

--5.c/ ZmienLiczbeMiejsc(id_wycieczki, liczba miejsc)



create or replace procedure ZmienLiczbeMiejsc(id_wycieczk WYCIECZKI.ID_WYCIECZKI%TYPE, liczba_miejs WYCIECZKI.LICZBA_MIEJSC%TYPE)

as
    zapisy integer;
    begin

        select count(*)  into zapisy from WYCIECZKI w JOIN REZERWACJE r
            on w.ID_WYCIECZKI = r.ID_WYCIECZKI
        where r.STATUS != 'A';

        if zapisy > liczba_miejs then
            raise_application_error(-20007,'Na wycieczke zapisalo sie wiecej osob');
        end if;

        UPDATE WYCIECZKI W
            SET W.LICZBA_MIEJSC = LICZBA_MIEJS
        WHERE id_wycieczki = id_wycieczk;
    end ZmienLiczbeMiejsc;

    begin
        ZmienLiczbeMiejsc(25,1);
    end;


--6 Tabela dziennikująca zmiany statusu rezerwacji


create table REZERWACJE_LOG(
    ID INT GENERATED ALWAYS AS IDENTITY NOT NULL,
    ID_REZERWACJI INT,
    DATA DATE,
    STATUS CHAR(1),
    CONSTRAINT REZERWACJE_LOG_PK PRIMARY KEY (
            ID
        ) ENABLE
);

select * from REZERWACJE_LOG;
-- zmiana procedur modyfikujących
create or replace procedure DodajRezerwacja_2(par_id_wycieczki integer, par_id_osoby integer)
as
    jest integer;
    rezerwacji_id integer;
    begin
        select count(*) into jest
        from OSOBY where ID_OSOBY = par_id_osoby;
        if jest = 0 then
            raise_application_error(-20000, 'Nie ma takiej osoby');
        end if;

        select count(*) into jest
        from WYCIECZKI where ID_WYCIECZKI = par_id_wycieczki;
        if jest = 0 then
            raise_application_error(-20004, 'Nie ma takiej wycieczki');
        end if;

        select sum(wolne_miejsca) into jest from (SELECT w.LICZBA_MIEJSC - count(r.NR_REZERWACJI)  as wolne_miejsca
            FROM WYCIECZKI w
            JOIN REZERWACJE r on w.ID_WYCIECZKI = r.ID_WYCIECZKI
            where w.ID_WYCIECZKI = par_id_wycieczki
            and r.STATUS != 'A'
            GROUP by w.LICZBA_MIEJSC);

        if jest - 1 < 0 then
             raise_application_error(-20006, 'Brak wolnych miejsc na tę wycieczkę');
        end if;

        select count(*) into jest
        from rezerwacje r
        where r.ID_WYCIECZKI = par_id_wycieczki
        and r.ID_OSOBY = par_id_osoby;
        if jest > 0
        then
            raise_application_error(-20007, 'Rezerwacja juz jest zrobiona');
        end if;

       insert into REZERWACJE (id_wycieczki, id_osoby, STATUS)
       values (par_id_wycieczki, par_id_osoby, 'N');

    select r.NR_REZERWACJI INTO rezerwacji_id FROM REZERWACJE r where r.ID_WYCIECZKI = par_id_wycieczki and r.ID_OSOBY = par_id_osoby;
    insert into REZERWACJE_LOG (ID_REZERWACJI, DATA, STATUS)
    values (rezerwacji_id, CURRENT_DATE, 'N');
    end DodajRezerwacja_2;

    select * from WYCIECZKI;
    select * from OSOBY;
    select * from WYCIECZKIDOSTEPNE;
    begin DodajRezerwacja_2(27,22); end;

        select * from REZERWACJE_LOG;
-- inne

create or replace procedure ZmienStatusRezerwacji(id_rezerwacji REZERWACJE.NR_REZERWACJI%TYPE,
                            nowy_status   REZERWACJE.STATUS%TYPE)
as
    jest integer;
    stary_status   REZERWACJE.STATUS%TYPE;
    begin
        select count(*) into jest
        from REZERWACJE where REZERWACJE.NR_REZERWACJI = id_rezerwacji;
        if jest = 0 then
            raise_application_error(-20004, 'Nie ma takiej rezerwacji');
        end if;

    SELECT status INTO stary_status
    FROM REZERWACJE
    WHERE NR_REZERWACJI = id_rezerwacji;

    CASE

      WHEN nowy_status = 'N'
      THEN
        raise_application_error(-20103,
                                'Istniejąca rezerwacja nie może stać się nowa');

      WHEN stary_status = 'A'
      THEN
        SELECT COUNT(*) INTO jest
        FROM WycieczkiDostepne wd
               JOIN REZERWACJE r ON r.ID_WYCIECZKI = wd.ID_WYCIECZKI
        WHERE r.NR_REZERWACJI = id_rezerwacji;

        IF jest = 0
        THEN
          raise_application_error(-20101,
                'Brak miejsc dla przywrócenia anulowanej rezerwacji');
        END IF;
    ELSE null;
    END CASE;

    UPDATE REZERWACJE
    SET STATUS = nowy_status
    WHERE NR_REZERWACJI = id_rezerwacji;

    INSERT INTO REZERWACJE_LOG (REZERWACJE_LOG.ID_REZERWACJI, DATA, STATUS)
    VALUES (id_rezerwacji, CURRENT_DATE, nowy_status);
    end ZmienStatusRezerwacji;

    begin ZmienStatusRezerwacji(61,'P'); end;
    select * from REZERWACJE_LOG;
--7 Zmiana strukury bazy danych
ALTER TABLE WYCIECZKI
  ADD liczba_wolnych_miejsc INT;

CREATE or replace View WycieczkiMiejsca_2
    AS
        SELECT
               w.ID_WYCIECZKI,
               w.Kraj,
               w.data,
               w.nazwa,
               w.LICZBA_MIEJSC,
               w.LICZBA_WOLNYCH_MIEJSC
        FROM WYCIECZKI w;



CREATE or replace View WycieczkiDostepne_2
    AS
        SELECT * FROM WycieczkiMiejsca_2
        WHERE liczba_wolnych_miejsc>0
        and data > sysdate;

create or replace procedure przelicz as
    begin
        update WYCIECZKI w
        set w.LICZBA_WOLNYCH_MIEJSC = w.LICZBA_MIEJSC - (select count(*) from REZERWACJE r
        where r.ID_WYCIECZKI = w.ID_WYCIECZKI and r.STATUS != 'A');
    end;

begin
    przelicz();
end;


--4.c/DostepneWycieczki(kraj, data_od, data_do)
CREATE OR REPLACE TYPE funkcja_7_wiersz AS object (
  kraj            VARCHAR(50),
  "data"          DATE,
  nazwa_wycieczki VARCHAR(100),
  liczba_miejsc number,
  liczba_wolnych_miejsc number
);

CREATE OR REPLACE TYPE funkcja_7_tablica IS TABLE OF funkcja_7_wiersz;


CREATE OR REPLACE
FUNCTION dostepnewycieczki_2(par_kraj    WYCIECZKI.KRAJ%TYPE, data_od DATE,
                            data_do DATE)
  return funkcja_7_tablica as v_ret funkcja_7_tablica;
  BEGIN
    IF data_do < data_od
    THEN
      raise_application_error(-20003, 'Nieprawidłowy przedział dat');
    END IF;

    SELECT funkcja_7_wiersz(w.kraj, w.data, w.nazwa, w.LICZBA_MIEJSC, w.liczba_wolnych_miejsc)
        BULK COLLECT INTO v_ret
    FROM WycieczkiDostepne_2 w
    WHERE w.KRAJ = par_kraj
      AND w.DATA >= data_od
      AND w.DATA <= data_do;
    return v_ret;
  end dostepnewycieczki_2;


  select dostepnewycieczki_2('Szczurolandia', '2020-04-01','2020-05-05') from dual;

--5.a/
create or replace procedure DodajRezerwacja_2(par_id_wycieczki integer, par_id_osoby integer)
as
    jest integer;
    rezerwacji_id integer;
    begin
        select count(*) into jest
        from OSOBY where ID_OSOBY = par_id_osoby;
        if jest = 0 then
            raise_application_error(-20000, 'Nie ma takiej osoby');
        end if;

        select count(*) into jest
        from WYCIECZKI where ID_WYCIECZKI = par_id_wycieczki;
        if jest = 0 then
            raise_application_error(-20004, 'Nie ma takiej wycieczki');
        end if;

        select liczba_wolnych_miejsc into jest from (select LICZBA_WOLNYCH_MIEJSC from WYCIECZKI where ID_WYCIECZKI = par_id_wycieczki);

        if jest - 1 < 0 then
             raise_application_error(-20006, 'Brak wolnych miejsc na tę wycieczkę');
        end if;

        select count(*) into jest
        from rezerwacje r
        where r.ID_WYCIECZKI = par_id_wycieczki
        and r.ID_OSOBY = par_id_osoby;
        if jest > 0
        then
            raise_application_error(-20007, 'Rezerwacja juz jest zrobiona');
        end if;

       insert into REZERWACJE (id_wycieczki, id_osoby, STATUS)
       values (par_id_wycieczki, par_id_osoby, 'N');


    UPDATE WYCIECZKI
    SET LICZBA_WOLNYCH_MIEJSC = LICZBA_WOLNYCH_MIEJSC - 1
    WHERE ID_WYCIECZKI = par_id_wycieczki;


    select "ISEQ$$_193606".currval INTO rezerwacji_id FROM dual;
    insert into REZERWACJE_LOG (ID_REZERWACJI, DATA, STATUS)
    values (rezerwacji_id, CURRENT_DATE, 'N');

    end;
select * from WycieczkiDostepne_2;
begin dodajrezerwacja_2(27,44);
end;

--5.b/ZmienStatusRezerwacji(nr_rezerwacji, status), procedura kontrolować czy możliwa jest zmiana statusu
create or replace procedure ZmienStatusRezerwacji_2(id_rezerwacji REZERWACJE.NR_REZERWACJI%TYPE,
                            nowy_status   REZERWACJE.STATUS%TYPE)
as
    jest integer;
    stary_status REZERWACJE.STATUS%TYPE;
      wolne_miejsca_delta integer;
    begin
        select count(*) into jest
        from REZERWACJE where REZERWACJE.NR_REZERWACJI = id_rezerwacji;
        if jest = 0 then
            raise_application_error(-20004, 'Nie ma takiej rezerwacji');
        end if;

    SELECT status INTO stary_status
    FROM REZERWACJE
    WHERE NR_REZERWACJI = id_rezerwacji;
       wolne_miejsca_delta := 0;
    CASE

      WHEN nowy_status = 'N'
      THEN
        raise_application_error(-20103,
                                'Istniejąca rezerwacja nie może stać się nowa');

      WHEN stary_status = 'A'
      THEN
        SELECT COUNT(*) INTO jest
        FROM WycieczkiDostepne_2 wd
               JOIN REZERWACJE r ON r.ID_WYCIECZKI = wd.id_wycieczki
        WHERE r.NR_REZERWACJI = id_rezerwacji;

        IF jest = 0
        THEN
          raise_application_error(-20101,
                                  'Brak miejsc dla przywrócenia anulowanej rezerwacji');
        END IF;
        IF nowy_status != 'A' THEN
        wolne_miejsca_delta := -1;
        END IF;
        ELSE
      IF nowy_status = 'A'
      THEN
        wolne_miejsca_delta := 1;
      ELSE
        wolne_miejsca_delta := 0;
      end if;
    END CASE;

    UPDATE REZERWACJE
    SET STATUS = nowy_status
    WHERE NR_REZERWACJI = id_rezerwacji;

    UPDATE WYCIECZKI w
    SET LICZBA_WOLNYCH_MIEJSC = LICZBA_WOLNYCH_MIEJSC + wolne_miejsca_delta
    WHERE w.ID_WYCIECZKI = (SELECT ID_WYCIECZKI
                            FROM REZERWACJE r
                            WHERE r.NR_REZERWACJI = id_rezerwacji);
    end ZmienStatusRezerwacji_2;

--5.c/ ZmienLiczbeMiejsc(id_wycieczki, liczba miejsc)
create or replace procedure ZmienLiczbeMiejsc_2(id_wycieczk WYCIECZKI.ID_WYCIECZKI%TYPE, liczba_miejs WYCIECZKI.LICZBA_MIEJSC%TYPE)

as
    zapisy integer;
    begin

        select count(*)  into zapisy from WYCIECZKI w JOIN REZERWACJE r
            on w.ID_WYCIECZKI = r.ID_WYCIECZKI
        where r.STATUS != 'A';

        if zapisy > liczba_miejs then
            raise_application_error(-20007,'Na wycieczke zapisalo sie wiecej osob');
        end if;

        UPDATE WYCIECZKI W
            SET W.LICZBA_MIEJSC = LICZBA_MIEJS
        WHERE id_wycieczki = id_wycieczk;

        UPDATE WYCIECZKI
        SET LICZBA_MIEJSC         = liczba_miejs,
            LICZBA_WOLNYCH_MIEJSC = LICZBA_WOLNYCH_MIEJSC +
                                (liczba_miejs - LICZBA_MIEJSC)
    WHERE ID_WYCIECZKI = id_wycieczk;

    end ZmienLiczbeMiejsc_2;

    begin
        ZmienLiczbeMiejsc(24,1);
    end;

select  * from WYCIECZKI;



--8 Zmiana strategii zapisywania do dziennika rezerwacji. Realizacja przy pomocy triggerów
--8.a
CREATE OR REPLACE TRIGGER dodanie_rezerwacji_trigger
  AFTER INSERT
  ON REZERWACJE
  FOR EACH ROW
  BEGIN
    INSERT INTO REZERWACJE_LOG (ID_REZERWACJI, DATA, STATUS)
    VALUES (:NEW.NR_REZERWACJI, CURRENT_DATE, :NEW.STATUS);
  end dodanie_rezerwacji_trigger;

create or replace procedure DodajRezerwacja_3(par_id_wycieczki integer, par_id_osoby integer)
as
    jest integer;
    rezerwacji_id integer;
    begin
        select count(*) into jest
        from OSOBY where ID_OSOBY = par_id_osoby;
        if jest = 0 then
            raise_application_error(-20000, 'Nie ma takiej osoby');
        end if;

        select count(*) into jest
        from WYCIECZKI where ID_WYCIECZKI = par_id_wycieczki;
        if jest = 0 then
            raise_application_error(-20004, 'Nie ma takiej wycieczki');
        end if;

        select liczba_wolnych_miejsc into jest from (select LICZBA_WOLNYCH_MIEJSC from WYCIECZKI where ID_WYCIECZKI = par_id_wycieczki);

        if jest - 1 < 0 then
             raise_application_error(-20006, 'Brak wolnych miejsc na tę wycieczkę');
        end if;

        select count(*) into jest
        from rezerwacje r
        where r.ID_WYCIECZKI = par_id_wycieczki
        and r.ID_OSOBY = par_id_osoby;
        if jest > 0
        then
            raise_application_error(-20007, 'Rezerwacja juz jest zrobiona');
        end if;

       insert into REZERWACJE (id_wycieczki, id_osoby, STATUS)
       values (par_id_wycieczki, par_id_osoby, 'N');
    UPDATE WYCIECZKI
    SET LICZBA_WOLNYCH_MIEJSC = LICZBA_WOLNYCH_MIEJSC - 1
    WHERE ID_WYCIECZKI = par_id_wycieczki;
    end;


--8.b/
CREATE OR REPLACE TRIGGER zmiana_statusu_trigger
  AFTER UPDATE
  ON REZERWACJE
  FOR EACH ROW
  DECLARE
    wolne_miejsca_delta int;
  BEGIN
    INSERT INTO REZERWACJE_LOG (ID_REZERWACJI, DATA, STATUS)
    VALUES (:NEW.NR_REZERWACJI, CURRENT_DATE, :NEW.STATUS);


    CASE
      WHEN :OLD.STATUS = 'A' AND :NEW.STATUS <> 'A'
      THEN
        wolne_miejsca_delta := -1;

      WHEN :OLD.STATUS <> 'A' AND :NEW.STATUS = 'A'
      THEN
        wolne_miejsca_delta := 1;
    ELSE
      wolne_miejsca_delta := 0;
    END CASE;
  end zmiana_statusu_trigger;


create or replace procedure ZmienStatusRezerwacji_3(id_rezerwacji REZERWACJE.NR_REZERWACJI%TYPE,
                            nowy_status   REZERWACJE.STATUS%TYPE)
as
    jest integer;
    stary_status REZERWACJE.STATUS%TYPE;
    wolne_miejsca_delta int;
    wycieczki_id int;
    begin
        select count(*) into jest
        from REZERWACJE where REZERWACJE.NR_REZERWACJI = id_rezerwacji;
        if jest = 0 then
            raise_application_error(-20004, 'Nie ma takiej rezerwacji');
        end if;

    SELECT status INTO stary_status
    FROM REZERWACJE
    WHERE NR_REZERWACJI = id_rezerwacji;

    CASE

      WHEN nowy_status = 'N'
      THEN
        raise_application_error(-20103,
                                'Istniejąca rezerwacja nie może stać się nowa');

      WHEN stary_status = 'A'
      THEN
        SELECT COUNT(*) INTO jest
        FROM WycieczkiDostepne_2 wd
               JOIN REZERWACJE r ON r.ID_WYCIECZKI = wd.id_wycieczki
        WHERE r.NR_REZERWACJI = id_rezerwacji;

        IF jest = 0
        THEN
          raise_application_error(-20101,
                                  'Brak miejsc dla przywrócenia anulowanej rezerwacji');
        END IF;
        IF nowy_status != 'A' THEN
        wolne_miejsca_delta := -1;
        END IF;
        ELSE
      IF nowy_status = 'A'
      THEN
        wolne_miejsca_delta := 1;
      ELSE
        wolne_miejsca_delta := 0;
      end if;
    END CASE;

    UPDATE REZERWACJE
    SET STATUS = nowy_status
    WHERE NR_REZERWACJI = id_rezerwacji;

        select id_wycieczki into wycieczki_id from REZERWACJE where REZERWACJE.NR_REZERWACJI = id_rezerwacji;

    UPDATE WYCIECZKI w
    SET LICZBA_WOLNYCH_MIEJSC = LICZBA_WOLNYCH_MIEJSC + wolne_miejsca_delta
    WHERE w.ID_WYCIECZKI = wycieczki_id;

    end ZmienStatusRezerwacji_3;



--8.c/

CREATE OR REPLACE TRIGGER zabronione_usuniecie_rezerwacji_trigger
  BEFORE DELETE
  ON REZERWACJE
  FOR EACH ROW
  BEGIN
    raise_application_error(-20300, 'Usuwanie rezerwacji jest zabronione');
  end;

--9

--9.a/


CREATE OR REPLACE TRIGGER dodanie_rezerwacji_trigger
  AFTER INSERT
  ON REZERWACJE
  FOR EACH ROW
  BEGIN
    INSERT INTO REZERWACJE_LOG (ID_REZERWACJI, DATA, STATUS)
    VALUES (:NEW.NR_REZERWACJI, CURRENT_DATE, :NEW.STATUS);

    UPDATE WYCIECZKI w
    SET LICZBA_WOLNYCH_MIEJSC = LICZBA_WOLNYCH_MIEJSC - 1
    WHERE w.ID_WYCIECZKI = :NEW.ID_WYCIECZKI;

  end dodanie_rezerwacji_trigger;

create or replace procedure DodajRezerwacja_3(par_id_wycieczki integer, par_id_osoby integer)
as
    jest integer;
    rezerwacji_id integer;
    begin
        select count(*) into jest
        from OSOBY where ID_OSOBY = par_id_osoby;
        if jest = 0 then
            raise_application_error(-20000, 'Nie ma takiej osoby');
        end if;

        select count(*) into jest
        from WYCIECZKI where ID_WYCIECZKI = par_id_wycieczki;
        if jest = 0 then
            raise_application_error(-20004, 'Nie ma takiej wycieczki');
        end if;

        select liczba_wolnych_miejsc into jest from (select LICZBA_WOLNYCH_MIEJSC from WYCIECZKI where ID_WYCIECZKI = par_id_wycieczki);

        if jest - 1 < 0 then
             raise_application_error(-20006, 'Brak wolnych miejsc na tę wycieczkę');
        end if;

        select count(*) into jest
        from rezerwacje r
        where r.ID_WYCIECZKI = par_id_wycieczki
        and r.ID_OSOBY = par_id_osoby;
        if jest > 0
        then
            raise_application_error(-20007, 'Rezerwacja juz jest zrobiona');
        end if;

       insert into REZERWACJE (id_wycieczki, id_osoby, STATUS)
       values (par_id_wycieczki, par_id_osoby, 'N');
    end;
--9.b/
CREATE OR REPLACE TRIGGER zmiana_statusu_trigger
  AFTER UPDATE
  ON REZERWACJE
  FOR EACH ROW
  DECLARE
    wolne_miejsca_delta int;
  BEGIN
    INSERT INTO REZERWACJE_LOG (ID_REZERWACJI, DATA, STATUS)
    VALUES (:NEW.NR_REZERWACJI, CURRENT_DATE, :NEW.STATUS);


    CASE
      WHEN :OLD.STATUS = 'A' AND :NEW.STATUS != 'A'
      THEN
        wolne_miejsca_delta := -1;

      WHEN :OLD.STATUS != 'A' AND :NEW.STATUS = 'A'
      THEN
        wolne_miejsca_delta := 1;
    ELSE
      wolne_miejsca_delta := 0;
    END CASE;

    UPDATE WYCIECZKI w
    SET LICZBA_WOLNYCH_MIEJSC = LICZBA_WOLNYCH_MIEJSC + wolne_miejsca_delta
    WHERE w.ID_WYCIECZKI = :NEW.ID_WYCIECZKI;
  end zmiana_statusu_trigger;




create or replace procedure ZmienStatusRezerwacji_3(id_rezerwacji REZERWACJE.NR_REZERWACJI%TYPE,
                            nowy_status   REZERWACJE.STATUS%TYPE)
as
    jest integer;
    stary_status REZERWACJE.STATUS%TYPE;
    begin
        select count(*) into jest
        from REZERWACJE where REZERWACJE.NR_REZERWACJI = id_rezerwacji;
        if jest = 0 then
            raise_application_error(-20004, 'Nie ma takiej rezerwacji');
        end if;

    SELECT status INTO stary_status
    FROM REZERWACJE
    WHERE NR_REZERWACJI = id_rezerwacji;

    CASE

      WHEN nowy_status = 'N'
      THEN
        raise_application_error(-20103,
                                'Istniejąca rezerwacja nie może stać się nowa');

      WHEN stary_status = 'A'
      THEN
        SELECT COUNT(*) INTO jest
        FROM WycieczkiDostepne_2 wd
               JOIN REZERWACJE r ON r.ID_WYCIECZKI = wd.ID_WYCIECZKI
        WHERE r.NR_REZERWACJI = id_rezerwacji;

        IF jest = 0
        THEN
          raise_application_error(-20101,
                                  'Brak miejsc dla przywrócenia anulowanej rezerwacji');
        END IF;
    ELSE null;
    END CASE;

    UPDATE REZERWACJE
    SET STATUS = nowy_status
    WHERE NR_REZERWACJI = id_rezerwacji;

    end ZmienStatusRezerwacji_3;

--9.c/
CREATE OR REPLACE TRIGGER zmiana_liczby_miejsc_trigger
  BEFORE UPDATE OF liczba_miejsc
  ON WYCIECZKI
  FOR EACH ROW
  BEGIN
    SELECT :OLD.LICZBA_WOLNYCH_MIEJSC +
           (:NEW.LICZBA_MIEJSC - :OLD.LICZBA_MIEJSC) INTO :NEW.LICZBA_WOLNYCH_MIEJSC
    FROM Dual;
  END;

create or replace procedure ZmienLiczbeMiejsc_3(id_wycieczk WYCIECZKI.ID_WYCIECZKI%TYPE, liczba_miejs WYCIECZKI.LICZBA_MIEJSC%TYPE)

as
    zapisy integer;
    begin

        select count(*)  into zapisy from WYCIECZKI w JOIN REZERWACJE r
            on w.ID_WYCIECZKI = r.ID_WYCIECZKI
        where r.STATUS != 'A';

        if zapisy > liczba_miejs then
            raise_application_error(-20007,'Na wycieczke zapisalo sie wiecej osob');
        end if;

        UPDATE WYCIECZKI W
            SET W.LICZBA_MIEJSC = LICZBA_MIEJS
        WHERE id_wycieczki = id_wycieczk;

    end ZmienLiczbeMiejsc_3;

    begin
        ZmienLiczbeMiejsc_3(24,1);
    end;

select  * from WYCIECZKI;