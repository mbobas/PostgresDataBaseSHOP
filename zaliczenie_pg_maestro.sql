---HURTOWNIA WIELOBRANŻOWA -MICHAŁ GULCZYŃSKI - NSI - GRUPA2. 
-- TABELE: KONTRAHENCI, PRODUKTY, MAGAZYN, DOSTAWY, SPRZEDAZ, FAKTURY. 
-- INDEXY: brak, ze wzgledu na to, że każda z tabel jest "żywym organizmem" cały czas możemy wykonywać na niej 
-- operacje DML - DELETE, UPDATE, INSERT. Z tego powodu trzeba by cały czas wykonywać update na indexach. 
-- Zdecydowałem się nie wykorzystywać indeksów z w/w powodu. 



CREATE DATABASE "zaliczenie" WITH
  OWNER = "postgres";

-- Przechowuje dane o kontrahentach - dostawcy i odbiorcy 
CREATE TABLE public.kontrahent (
  id_kontrahenta  serial NOT NULL PRIMARY KEY,
  nazwa           text NOT NULL,
  nip             numeric(15),
  tel         varchar(30),
  ulica           text,
  kod_pocztowy    text,
  miasto          text,
  dostawca boolean NOT NULL,
  odbiorca boolean NOT NULL
);

-- przechowuje listę produktów w hurtowni
CREATE TABLE public.produkty (
  produkt_id  serial NOT NULL PRIMARY KEY,
  nazwa       text NOT NULL,
  waga        double precision DEFAULT 0,
  cena        double precision NOT NULL,
  id_kategoria integer NOT NULL
);

-- przechowuje historię dostaw 
  CREATE TABLE public.dostawa (
  id_dostawy      serial NOT NULL PRIMARY KEY,
  id_kontrahenta  integer NOT NULL,
  produkt1_id     integer NOT NULL,
  ilosc1          integer NOT NULL,
  produkt2_id     integer,
  ilosc2          integer,
  produkt3_id     integer,
  ilosc3          integer,
  data_dostawy date NOT NULL,
  CONSTRAINT id_kontrahenta
    FOREIGN KEY (id_kontrahenta)
    REFERENCES public.kontrahent(id_kontrahenta),
  CONSTRAINT produkt1_id
    FOREIGN KEY (produkt1_id)
    REFERENCES public.produkty(produkt_id),
  CONSTRAINT produkt2_id
    FOREIGN KEY (produkt2_id)
    REFERENCES public.produkty(produkt_id), 
  CONSTRAINT produkt3_id
    FOREIGN KEY (produkt3_id)
    REFERENCES public.produkty(produkt_id)
);

-- saldo magazynu hurtowni (1 magazyn)
CREATE TABLE public.magazyn (
  produkt_id  integer NOT NULL PRIMARY KEY,
  ilosc       integer DEFAULT 0,
  CONSTRAINT produkt
    FOREIGN KEY (produkt_id)
    REFERENCES public.produkty(produkt_id)
    DEFERRABLE
    INITIALLY IMMEDIATE
);

-- tabela przechowuje dane sprzedazy, na jej podstawie aktualizujemy magazyn lub wystawiamy fakturę/paragon. 
CREATE TABLE public.sprzedaz (
  id_sprzedazy    serial NOT NULL PRIMARY KEY,
  id_kontrahenta  integer NOT NULL,
  produkt1_id     integer NOT NULL,
  ilosc1          integer NOT NULL,
  produkt2_id     integer,
  ilosc2          integer,
  produkt3_id     integer,
  ilosc3          integer,
  data_sprzedazy  date NOT NULL,
  ilosc_pozycji   integer NOT NULL,
  CONSTRAINT id_kontrahenta
    FOREIGN KEY (id_kontrahenta)
    REFERENCES public.kontrahent(id_kontrahenta), 
  CONSTRAINT produkt1_id
    FOREIGN KEY (produkt1_id)
    REFERENCES public.produkty(produkt_id), 
  CONSTRAINT produkt2_id
    FOREIGN KEY (produkt2_id)
    REFERENCES public.produkty(produkt_id), 
  CONSTRAINT produkt3_id
    FOREIGN KEY (produkt3_id)
    REFERENCES public.produkty(produkt_id)
);

-- tabela przechowuje kategorie produktow 
CREATE TABLE public.kategoria (
  id_kategoria  serial NOT NULL PRIMARY KEY,
  nazwa         text NOT NULL,
 /* Foreign keys */
  CONSTRAINT id_kategoria
    FOREIGN KEY (id_kategoria)
    REFERENCES public.kategoria(id_kategoria)
);

-- tabela generowana automatycznie po wsytawieniu dokuemntu sprzedazy, w przyszlosci mozna dodac tabele np. paragony
CREATE TABLE public.faktury (
  id_faktury         serial NOT NULL PRIMARY KEY,
  nazwa_kontrahenta  text NOT NULL,
  nip                numeric(15),
  produkt1_id        integer,
  ilosc1             integer,
  produkt2_id        integer,
  ilosc2             integer,
  produkt3_id        integer,
  ilosc3             integer,
  suma_netto         double precision,
  suma_brutto        double precision
);


---FUNKCJA I TRIGGER: Automatyczne dodawanie produktu do tabeli: magazyn, po dodaniu produktu do bazy, zeby pozniej można było
-- go UPDATOWAĆ po dostawie lub sprzedazy.

CREATE OR REPLACE FUNCTION automat_prod_na_mag()
  RETURNS trigger AS
$$
BEGIN
         INSERT INTO magazyn(produkt_id,ilosc)
         VALUES(NEW.produkt_id, 0);
 
    RETURN NEW;
END;
$$
LANGUAGE 'plpgsql';

CREATE TRIGGER trig_prod_na_mag
  AFTER INSERT
  ON produkty
  FOR EACH ROW
  EXECUTE PROCEDURE automat_prod_na_mag();

  --TEST FUNKCJI I TRIGGERA: automat_prod_na_mag()
  -- INSERT INTO produkty(nazwa, waga, cena) VALUES ('xx', 0.25, 2); 


-- FUNKCJA I TRIGGER: UPDATE stanu magazynu po dostawie produktu 1-3 pozycji na dokumencie dostawy.
CREATE OR REPLACE FUNCTION dodaj_na_mag()
  RETURNS trigger AS
$$
BEGIN 
      IF NEW.ilosc1 >0 THEN
         UPDATE magazyn SET ilosc= ilosc + NEW.ilosc1
         WHERE produkt_id=NEW.produkt1_id;
      END IF;
      IF NEW.ilosc2 >0 THEN
         UPDATE magazyn SET ilosc= ilosc + NEW.ilosc2
         WHERE produkt_id=NEW.produkt2_id;
      END IF;
      IF NEW.ilosc3 >0 THEN
         UPDATE magazyn SET ilosc= ilosc + NEW.ilosc3
         WHERE produkt_id=NEW.produkt3_id;
      END IF;
    RETURN NEW;
END;
$$
LANGUAGE 'plpgsql';


CREATE TRIGGER trig_dodaj
  BEFORE INSERT
  ON dostawa
  FOR EACH ROW
  EXECUTE PROCEDURE dodaj_na_mag();
  
-- TEST FUKCJI POWYZEJ dodaj_na_mag(); 
-- INSERT INTO dostawa(id_kontrahenta, produkt1_id, ilosc1, produkt2_id, ilosc2, produkt3_id, ilosc3, data_dostawy) VALUES (1, 10, 2, 18, 3, 20, 10, '2020-12-09');
-- INSERT INTO dostawa(id_kontrahenta, produkt1_id, ilosc1, produkt2_id, ilosc2, produkt3_id, ilosc3, data_dostawy) VALUES (2, 11, 2, 19, 3, 20, 10, '2020-12-09');
-- INSERT INTO dostawa(id_kontrahenta, produkt1_id, ilosc1, produkt2_id, ilosc2, produkt3_id, ilosc3, data_dostawy) VALUES (3, 12, 2, 20, 3, 20, 10, '2020-12-09');
-- INSERT INTO dostawa(id_kontrahenta, produkt1_id, ilosc1, produkt2_id, ilosc2, produkt3_id, ilosc3, data_dostawy) VALUES (4, 13, 2, 21, 3, 20, 10, '2020-12-09');
-- INSERT INTO dostawa(id_kontrahenta, produkt1_id, ilosc1, produkt2_id, ilosc2, produkt3_id, ilosc3, data_dostawy) VALUES (5, 14, 2, 22, 3, 20, 10, '2020-12-09');
-- INSERT INTO dostawa(id_kontrahenta, produkt1_id, ilosc1, produkt2_id, ilosc2, produkt3_id, ilosc3, data_dostawy) VALUES (6, 15, 2, 23, 3, 20, 10, '2020-12-09');
-- INSERT INTO dostawa(id_kontrahenta, produkt1_id, ilosc1, produkt2_id, ilosc2, produkt3_id, ilosc3, data_dostawy) VALUES (7, 16, 2, 11, 3, 20, 10, '2020-12-09');
-- INSERT INTO dostawa(id_kontrahenta, produkt1_id, ilosc1, produkt2_id, ilosc2, produkt3_id, ilosc3, data_dostawy) VALUES (8, 17, 2, 11, 3, 20, 10, '2020-12-09');


-- FUNKCJA I TRIGGER: Automatyczny UPDATE stanu magazynu po sprzedazy produktu - 1-3 pozycji na dokumencie sprzedazy. 
CREATE OR REPLACE FUNCTION odejmij_z_mag()
  RETURNS trigger AS
$$
BEGIN 
      IF NEW.ilosc1 >0 THEN
         UPDATE magazyn SET ilosc= ilosc - NEW.ilosc1
         WHERE produkt_id=NEW.produkt1_id;
      END IF;
      IF NEW.ilosc2 >0 THEN
         UPDATE magazyn SET ilosc= ilosc - NEW.ilosc2
         WHERE produkt_id=NEW.produkt2_id;
      END IF;
      IF NEW.ilosc3 >0 THEN
         UPDATE magazyn SET ilosc= ilosc - NEW.ilosc3
         WHERE produkt_id=NEW.produkt3_id;
      END IF;
    RETURN NEW;
END;
$$
LANGUAGE 'plpgsql';


CREATE TRIGGER trig_odejmij_z_mag
  BEFORE INSERT
  ON sprzedaz
  FOR EACH ROW
  EXECUTE PROCEDURE odejmij_z_mag()

  --TEST FUNKCJA I TRIGGERA odejmij_z_mag()
-- INSERT INTO sprzedaz(id_kontrahenta, produkt1_id,  ilosc1, produkt2_id, ilosc2, produkt3_id, ilosc3, data_sprzedazy, ilosc_pozycji) VALUES (8, 17, 2, 11, 3, 20, 10, '2020-12-09', TRUE, 3);




-- FUNKCJA I TRIGGER:
-- Automatyczne wystawianie dokument faktury po wprowadzeniu sprzedazy 
-- ilosc produktow na fakturze 1-3
-- automatyczne liczenie sumy netto oraz brutto

CREATE OR REPLACE FUNCTION public.wystaw_fv()
RETURNS trigger AS
$$
BEGIN 
      IF NEW.ilosc_pozycji = 1  THEN  
        INSERT INTO public.faktury(nazwa_kontrahenta, nip, produkt1_id, ilosc1, suma_netto, suma_brutto)
        VALUES ((SELECT nazwa
        FROM kontrahent 
        WHERE id_kontrahenta = NEW.id_kontrahenta),
        (SELECT nip
        FROM kontrahent 
        WHERE id_kontrahenta = NEW.id_kontrahenta), NEW.produkt1_id, NEW.ilosc1,
        (SELECT cena
        FROM produkty 
        WHERE produkt_id = NEW.produkt1_id), 
        (SELECT cena
        FROM produkty 
        WHERE produkt_id = NEW.produkt1_id)*1.23
        );
      ELSEIF NEW.ilosc_pozycji = 2  THEN  
        INSERT INTO public.faktury(nazwa_kontrahenta, nip, produkt1_id, ilosc1, produkt2_id, ilosc2, suma_netto, suma_brutto)
        VALUES ((SELECT nazwa
        FROM kontrahent 
        WHERE id_kontrahenta = NEW.id_kontrahenta),
        (SELECT nip
        FROM kontrahent 
        WHERE id_kontrahenta = NEW.id_kontrahenta), NEW.produkt1_id, NEW.ilosc1, NEW.produkt2_id, NEW.ilosc2,
        (SELECT cena
        FROM produkty 
        WHERE produkt_id = NEW.produkt1_id) +
        (SELECT cena
        FROM produkty 
        WHERE produkt_id = NEW.produkt2_id),
        (SELECT cena
        FROM produkty 
        WHERE produkt_id = NEW.produkt1_id) +
        (SELECT cena
        FROM produkty 
        WHERE produkt_id = NEW.produkt2_id)*1.23
        );
      ELSEIF NEW.ilosc_pozycji = 3  THEN  
        INSERT INTO public.faktury(nazwa_kontrahenta, nip, produkt1_id, ilosc1, produkt2_id, ilosc2, produkt3_id, ilosc3, suma_netto, suma_brutto)
        VALUES ((SELECT nazwa
        FROM kontrahent 
        WHERE id_kontrahenta = NEW.id_kontrahenta),
        (SELECT nip
        FROM kontrahent 
        WHERE id_kontrahenta = NEW.id_kontrahenta), NEW.produkt1_id, NEW.ilosc1, NEW.produkt2_id, NEW.ilosc2, NEW.produkt3_id, NEW.ilosc3, 
        (SELECT cena
        FROM produkty 
        WHERE produkt_id = NEW.produkt1_id) +
        (SELECT cena
        FROM produkty 
        WHERE produkt_id = NEW.produkt2_id) +
        (SELECT cena
        FROM produkty 
        WHERE produkt_id = NEW.produkt3_id), 
        (SELECT cena
        FROM produkty 
        WHERE produkt_id = NEW.produkt1_id) +
        (SELECT cena
        FROM produkty 
        WHERE produkt_id = NEW.produkt2_id) +
        (SELECT cena
        FROM produkty 
        WHERE produkt_id = NEW.produkt3_id)*1.23
        );
      END IF;  
      RETURN NEW;
END;
$$
LANGUAGE 'plpgsql';


CREATE TRIGGER trig_wystaw_fv
  BEFORE INSERT
  ON sprzedaz
  FOR EACH ROW
  EXECUTE PROCEDURE wystaw_fv()

  
--Test FUNKCJI I TRIGGERA: 
--wprowadzanie sprzedazy dla róznej ilosci produktów - triger wystawiajacy automatycznie fakturę 
-- INSERT INTO sprzedaz(id_kontrahenta, produkt1_id, ilosc1, produkt2_id, ilosc2, produkt3_id, ilosc3, data_sprzedazy, ilosc_pozycji) 
-- VALUES (8, 17, 2, 11, 3, 20, 10, '2020-12-09', TRUE, 1);

INSERT INTO kategoria(nazwa) VALUES ('WARZYWA'); 
INSERT INTO kategoria(nazwa) VALUES ('ALKOHOLE'); 
INSERT INTO kategoria(nazwa) VALUES ('SŁODYCZE'); 
INSERT INTO kategoria(nazwa) VALUES ('NAPOJE'); 


INSERT INTO produkty(nazwa, waga, cena, id_kategoria) VALUES ('czosnek', 0.2, 1.99, 1); 
INSERT INTO produkty(nazwa, waga, cena, id_kategoria) VALUES ('ziemniaki', 1, 3.99, 1);
INSERT INTO produkty(nazwa, waga, cena, id_kategoria) VALUES ('pomidory', 1.1, 12.00, 1); 
INSERT INTO produkty(nazwa, waga, cena, id_kategoria) VALUES ('kalafior', 1, 4.99, 1); 
INSERT INTO produkty(nazwa, waga, cena, id_kategoria) VALUES ('ogorek', 0.5, 2.99, 1); 
INSERT INTO produkty(nazwa, waga, cena, id_kategoria) VALUES ('rzodkiewka', 0.2, 1.99, 1); 
INSERT INTO produkty(nazwa, waga, cena, id_kategoria) VALUES ('papryka', 1, 9.99, 1); 
INSERT INTO produkty(nazwa, waga, cena, id_kategoria) VALUES ('kalarepa', 0.25, 2.50, 1); 

INSERT INTO produkty(nazwa, waga, cena, id_kategoria) VALUES ('Lech', 0.5, 3.99, 2); 
INSERT INTO produkty(nazwa, waga, cena, id_kategoria) VALUES ('Książęce', 0.5, 4.50, 2);
INSERT INTO produkty(nazwa, waga, cena, id_kategoria) VALUES ('Calsberg', 0.5, 2.99, 2); 
INSERT INTO produkty(nazwa, waga, cena, id_kategoria) VALUES ('Żywiec', 0.5, 3.89, 2); 
INSERT INTO produkty(nazwa, waga, cena, id_kategoria) VALUES ('Bols', 0.5, 29.99, 2); 
INSERT INTO produkty(nazwa, waga, cena, id_kategoria) VALUES ('Bols ', 0.7, 38.99, 2); 
INSERT INTO produkty(nazwa, waga, cena, id_kategoria) VALUES ('Jack Daniels', 0.7, 74.99, 2); 
INSERT INTO produkty(nazwa, waga, cena, id_kategoria) VALUES ('Williams', 0.5, 29.99, 2); 

INSERT INTO produkty(nazwa, waga, cena, id_kategoria) VALUES ('Milka 330g', 0.33, 11.99, 3); 
INSERT INTO produkty(nazwa, waga, cena, id_kategoria) VALUES ('Milka 100g', 0.1, 4.50, 3);
INSERT INTO produkty(nazwa, waga, cena, id_kategoria) VALUES ('Wafelki Krakus', 0.350, 4.99, 3); 
INSERT INTO produkty(nazwa, waga, cena, id_kategoria) VALUES ('Ferrero', 0.180, 8.89, 2); 
INSERT INTO produkty(nazwa, waga, cena, id_kategoria) VALUES ('Kulki Czekoladowe', 0.30, 3.99, 3); 
INSERT INTO produkty(nazwa, waga, cena, id_kategoria) VALUES ('Wafle Kokosowe ', 0.25, 5.99, 3); 
INSERT INTO produkty(nazwa, waga, cena, id_kategoria) VALUES ('Herbatniki', 0.11, 2.79, 3); 
INSERT INTO produkty(nazwa, waga, cena, id_kategoria) VALUES ('Kinder Bueno', 0.1, 1.99, 3); 

INSERT INTO produkty(nazwa, waga, cena, id_kategoria) VALUES ('Mirinda', 0.1, 1.99, 4); 
INSERT INTO produkty(nazwa, waga, cena, id_kategoria) VALUES ('Coca-Cola', 0.1, 1.99, 4); 
INSERT INTO produkty(nazwa, waga, cena, id_kategoria) VALUES ('Fanta', 0.1, 1.99, 4); 
INSERT INTO produkty(nazwa, waga, cena, id_kategoria) VALUES ('7-UP', 0.1, 1.99, 4); 
INSERT INTO produkty(nazwa, waga, cena, id_kategoria) VALUES ('Pepesi', 0.1, 1.99, 4); 
INSERT INTO produkty(nazwa, waga, cena, id_kategoria) VALUES ('Sprite', 0.1, 1.99, 4); 
INSERT INTO produkty(nazwa, waga, cena, id_kategoria) VALUES ('Mountain-Dew', 0.1, 1.99, 4); 
INSERT INTO produkty(nazwa, waga, cena, id_kategoria) VALUES ('Cola Zero', 0.1, 1.99, 4); 
INSERT INTO produkty(nazwa, waga, cena, id_kategoria) VALUES ('Pepsi Zero', 0.1, 1.99, 4); 

--odbiorcy 1-7
INSERT INTO kontrahent(nazwa, nip, tel, ulica, kod_pocztowy, miasto, dostawca, odbiorca) VALUES ('Michal Gulczynski', 8810205891, '785612622', 'Testowa 14', '87-100', 'Torun', FALSE, TRUE); 
INSERT INTO kontrahent(nazwa, nip, tel, ulica, kod_pocztowy, miasto, dostawca, odbiorca) VALUES ('Stefan Stivi', 771021111, '666555888', 'Kwadratowa 15', '87-100', 'Golub-Dobrzyń', FALSE, TRUE); 
INSERT INTO kontrahent(nazwa, nip, tel, ulica, kod_pocztowy, miasto, dostawca, odbiorca) VALUES ('Marta Niewarta', 9105117891, '888654123', 'Wodna 1', '87-300', 'Brodnica', FALSE, TRUE); 
INSERT INTO kontrahent(nazwa, nip, tel, ulica, kod_pocztowy, miasto, dostawca, odbiorca) VALUES ('Sławomir Szymański', 874555666, '745896321', 'Psia 1', '87-100', 'Łysomice', FALSE, TRUE);
INSERT INTO kontrahent(nazwa, nip, tel, ulica, kod_pocztowy, miasto, dostawca, odbiorca) VALUES ('Marcin Marcinkowski', 9876663322, '874256321', 'Krabowa 14', '87-100', 'Torun', FALSE, TRUE); 
INSERT INTO kontrahent(nazwa, nip, tel, ulica, kod_pocztowy, miasto, dostawca, odbiorca) VALUES ('POLMARKET', 9874445599, '459863258', 'Kamienna 15', '22-000', 'Warszawa', FALSE, TRUE); 
INSERT INTO kontrahent(nazwa, nip, tel, ulica, kod_pocztowy, miasto, dostawca, odbiorca) VALUES ('BIEDRONKA', 985632258, '666555888', 'Drzewna 15', '22-000', 'Warszawa', FALSE, TRUE); 

-- dostawcy
--8-13
INSERT INTO kontrahent(nazwa, nip, tel, ulica, kod_pocztowy, miasto, dostawca, odbiorca) VALUES ('HURT_DETAL', 9886552233, '123123122', 'Lososiowa 1', '18-800', 'Kraków', TRUE, FALSE); 
INSERT INTO kontrahent(nazwa, nip, tel, ulica, kod_pocztowy, miasto, dostawca, odbiorca) VALUES ('HURT_DETAL2', 8741568877, '321654987', 'Lwia 1', '33-300', 'Poznań', TRUE, FALSE); 
INSERT INTO kontrahent(nazwa, nip, tel, ulica, kod_pocztowy, miasto, dostawca, odbiorca) VALUES ('PPHU-OWOCE-WARZYWA', 8741598866, '369258147', 'Mostowa 1', '87-100', 'Łysomice', TRUE, FALSE); 
INSERT INTO kontrahent(nazwa, nip, tel, ulica, kod_pocztowy, miasto, dostawca, odbiorca) VALUES ('ALKOHOLE ŚWIATA', 9568884512, '789321456', 'Dworcowa 1', '87-100', 'Łysomice', TRUE, FALSE); 
INSERT INTO kontrahent(nazwa, nip, tel, ulica, kod_pocztowy, miasto, dostawca, odbiorca) VALUES ('PIEKARNIA MIŚ', 8741569944, '111223366', 'Jednolita 1', '87-100', 'Łysomice', TRUE, FALSE); 
INSERT INTO kontrahent(nazwa, nip, tel, ulica, kod_pocztowy, miasto, dostawca, odbiorca) VALUES ('PPHU ZABAWKI', 8769994548, '2244889966', 'Abstrakcyjna 1', '87-100', 'Łysomice', TRUE, FALSE); 


-- wprowadzanie dokumentu dostawy - ilosci od 1-3 produktow 
INSERT INTO dostawa(id_kontrahenta, produkt1_id, ilosc1, produkt2_id, ilosc2, produkt3_id, ilosc3, data_dostawy) 
VALUES (1, 1, 20, 2, 30, 3, 11, '2020-12-09');
INSERT INTO dostawa(id_kontrahenta, produkt1_id, ilosc1, produkt2_id, ilosc2, produkt3_id, ilosc3, data_dostawy) 
VALUES (2, 4, 20, 5, 10, 6, 12, '2020-12-10');
INSERT INTO dostawa(id_kontrahenta, produkt1_id, ilosc1, produkt2_id, ilosc2, produkt3_id, ilosc3, data_dostawy) 
VALUES (3, 7, 20, 8, 10, 9, 12, '2020-12-11');
INSERT INTO dostawa(id_kontrahenta, produkt1_id, ilosc1, produkt2_id, ilosc2, produkt3_id, ilosc3, data_dostawy) 
VALUES (4, 10, 44, 11, 33, 12, 32, '2020-12-12');
INSERT INTO dostawa(id_kontrahenta, produkt1_id, ilosc1, produkt2_id, ilosc2, produkt3_id, ilosc3, data_dostawy) 
VALUES (5, 13, 44, 14, 11, 15, 32, '2020-12-13');
INSERT INTO dostawa(id_kontrahenta, produkt1_id, ilosc1, produkt2_id, ilosc2, produkt3_id, ilosc3, data_dostawy) 
VALUES (6, 16, 4, 17, 7, 18, 8, '2020-12-14');
INSERT INTO dostawa(id_kontrahenta, produkt1_id, ilosc1, produkt2_id, ilosc2, produkt3_id, ilosc3, data_dostawy) 
VALUES (7, 10, 4, 30, 7, 21, 22, '2020-12-15');

INSERT INTO dostawa(id_kontrahenta, produkt1_id, ilosc1, produkt2_id, ilosc2, produkt3_id, ilosc3, data_dostawy) 
VALUES (7, 22, 4, 23, 7, 24, 22, '2020-12-15');
INSERT INTO dostawa(id_kontrahenta, produkt1_id, ilosc1, produkt2_id, ilosc2, produkt3_id, ilosc3, data_dostawy) 
VALUES (6, 25, 44, 26, 1, 27, 14, '2020-12-15');
INSERT INTO dostawa(id_kontrahenta, produkt1_id, ilosc1, produkt2_id, ilosc2, produkt3_id, ilosc3, data_dostawy) 
VALUES (5, 28, 14, 29, 6, 30, 39, '2020-12-14');
INSERT INTO dostawa(id_kontrahenta, produkt1_id, ilosc1, produkt2_id, ilosc2, produkt3_id, ilosc3, data_dostawy) 
VALUES (4, 31, 54, 32, 5, 33, 12, '2020-12-15');

INSERT INTO dostawa(id_kontrahenta, produkt1_id, ilosc1, produkt2_id, ilosc2, data_dostawy) 
VALUES (4, 19, 100, 20, 500, '2020-12-15');


-- dodawanie sprzedazy - po czym automatycznie wystawiamy fakturę 
-- faktura moze zawierac rózne ilosci produktów w przedziale 1-3
INSERT INTO sprzedaz(id_kontrahenta, produkt1_id, ilosc1, produkt2_id, ilosc2, produkt3_id, ilosc3, data_sprzedazy, ilosc_pozycji) 
VALUES (8, 3, 2, 4, 3, 5, 10, '2020-12-15', 3);
INSERT INTO sprzedaz(id_kontrahenta, produkt1_id, ilosc1, produkt2_id, ilosc2, produkt3_id, ilosc3, data_sprzedazy, ilosc_pozycji) 
VALUES (10, 6, 3, 7, 3, 8, 10, '2020-12-15', 3);
INSERT INTO sprzedaz(id_kontrahenta, produkt1_id, ilosc1, produkt2_id, ilosc2, produkt3_id, ilosc3, data_sprzedazy, ilosc_pozycji) 
VALUES (12, 10, 2, 11, 2, 12, 1, '2020-12-15', 3);
INSERT INTO sprzedaz(id_kontrahenta, produkt1_id, ilosc1, produkt2_id, ilosc2, produkt3_id, ilosc3, data_sprzedazy, ilosc_pozycji) 
VALUES (13, 13, 2, 14, 3, 15, 1, '2020-12-14', 3);
INSERT INTO sprzedaz(id_kontrahenta, produkt1_id, ilosc1, produkt2_id, ilosc2, data_sprzedazy, ilosc_pozycji) 
VALUES (9, 1, 2, 2, 3,  '2020-12-15', 2);
INSERT INTO sprzedaz(id_kontrahenta, produkt1_id, ilosc1, produkt2_id, ilosc2, data_sprzedazy, ilosc_pozycji) 
VALUES (9, 33, 2, 14, 3,  '2020-12-15', 2);
INSERT INTO sprzedaz(id_kontrahenta, produkt1_id, ilosc1, produkt2_id, ilosc2, data_sprzedazy, ilosc_pozycji) 
VALUES (9, 32, 2, 22, 3,  '2020-12-15', 2);
INSERT INTO sprzedaz(id_kontrahenta, produkt1_id, ilosc1, data_sprzedazy, ilosc_pozycji) 
VALUES (13, 27, 2, '2020-12-09', 1);
INSERT INTO sprzedaz(id_kontrahenta, produkt1_id, ilosc1, data_sprzedazy, ilosc_pozycji) 
VALUES (11, 26, 3, '2020-12-15', 1);

select * from faktury;