select * from OSOBY

select * from wycieczki

select * from REZERWACJE


--3.a/
CREATE VIEW RezerwacjeWszystkie
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

select * from REZERWACJEWSZYSTKIE
--3.b/
CREATE VIEW RezerwacjePotwierdzone
    AS
        SELECT *
        FROM REZERWACJEWSZYSTKIE r
        WHERE r.STATUS = 'P';

select * from REZERWACJEPOTWIERDZONE
--3.c/
CREATE View RezerwacjeWPrzyszlosci
    AS
        SELECT *
        FROM REZERWACJEWSZYSTKIE
        WHERE rezerwacjewszystkie.DATA > sysdate
--3.d/
CREATE View WycieczkiMiejsca
    AS
        SELECT
               w.Kraj,
               w.data,
               w.nazwa,
               w.LICZBA_MIEJSC,
               w.LICZBA_MIEJSC - count(r.NR_REZERWACJI) as wolne_miejsca
        FROM WYCIECZKI w
        JOIN REZERWACJE r on w.ID_WYCIECZKI = r.ID_WYCIECZKI
        JOIN OSOBY o on r.ID_OSOBY = o.ID_OSOBY
        GROUP BY w.Kraj, w.data, w.nazwa, w.LICZBA_MIEJSC;

--3.e/
CREATE View WycieczkiDostepne
    AS
        SELECT * FROM WycieczkiMiejsca
        WHERE wolne_miejsca>0
        and data > sysdate;

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
    WHERE r.ID_WYCIECZKI = id;
    return v_ret;
  end uczestnicywycieczki;

  select uczestnicywycieczki(26) from dual;
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

    select * from WycieczkiDostepne

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

begin dodajrezerwacja(25,45);
end;

--5.b/ZmienStatusRezerwacji(nr_rezerwacji, status), procedura kontrolować czy możliwa jest zmiana statusu



--5.c/
