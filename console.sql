CREATE DATABASE IF NOT EXISTS torneo_futbol5
    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE torneo_futbol5;

-- ============ USUARIOS DE LA APP ============
CREATE TABLE login (
                       correo      VARCHAR(100) PRIMARY KEY,
                       contrasena  VARCHAR(255) NOT NULL,              -- hash, no texto plano
                       rol         ENUM('administrador','planillero') NOT NULL,
                       CHECK (correo LIKE '%_@_%._%')
);

-- ============ MAESTROS ============
CREATE TABLE facultad (
                          id_facultad INT AUTO_INCREMENT PRIMARY KEY,
                          nombre      VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE jugador (
                         ci               VARCHAR(8)   PRIMARY KEY,
                         nombre           VARCHAR(50)  NOT NULL,
                         apellido         VARCHAR(50)  NOT NULL,
                         email            VARCHAR(100) NOT NULL UNIQUE,
                         fecha_nacimiento DATE         NOT NULL,
                         id_facultad      INT          NOT NULL,
                         tipo             ENUM('grado','posgrado','docente','funcionario') NOT NULL,
                         FOREIGN KEY (id_facultad) REFERENCES facultad(id_facultad),
                         CHECK (ci REGEXP '^[0-9]{7,8}$'),
                         CHECK (email LIKE '%_@_%._%')
);

CREATE TABLE complejo (
                          id_complejo  INT AUTO_INCREMENT PRIMARY KEY,
                          nombre       VARCHAR(100) NOT NULL UNIQUE,
                          direccion    VARCHAR(150) NOT NULL,
                          departamento VARCHAR(50)  NOT NULL
);

CREATE TABLE cancha (
                        nombre_cancha VARCHAR(50) NOT NULL,
                        id_complejo   INT         NOT NULL,
                        superficie    ENUM('sintetico','parquet') NOT NULL,
                        techada       BOOLEAN     NOT NULL DEFAULT FALSE,
                        PRIMARY KEY (nombre_cancha, id_complejo),
                        FOREIGN KEY (id_complejo) REFERENCES complejo(id_complejo)
);

CREATE TABLE turno (
                       id_turno    INT AUTO_INCREMENT PRIMARY KEY,
                       hora_inicio TIME NOT NULL,
                       hora_fin    TIME NOT NULL,
                       UNIQUE (hora_inicio),
                       CHECK (hora_inicio < hora_fin),
                       CHECK (hora_inicio >= '18:00:00' AND hora_fin <= '23:00:00')
);

-- ============ TORNEO ============
CREATE TABLE torneo (
                        id_torneo    INT AUTO_INCREMENT PRIMARY KEY,
                        nombre       VARCHAR(100) NOT NULL,
                        anio         INT          NOT NULL,
                        semestre     TINYINT      NOT NULL,
                        fecha_inicio DATE         NOT NULL,
                        fecha_fin    DATE         NOT NULL,
                        estado       ENUM('inscripcion','en_curso','finalizado')
                                                  NOT NULL DEFAULT 'inscripcion',
                        UNIQUE (anio, semestre),
                        CHECK (semestre IN (1,2)),
                        CHECK (fecha_inicio <= fecha_fin)
);

CREATE TABLE fecha_torneo (
                              id_torneo    INT NOT NULL,
                              numero_fecha INT NOT NULL,
                              fecha_desde  DATE NOT NULL,
                              fecha_hasta  DATE NOT NULL,
                              PRIMARY KEY (id_torneo, numero_fecha),
                              FOREIGN KEY (id_torneo) REFERENCES torneo(id_torneo),
                              CHECK (numero_fecha >= 1),
                              CHECK (fecha_desde <= fecha_hasta)
);

-- ============ EQUIPOS Y PLANTELES ============
CREATE TABLE equipo (
                        id_equipo   INT AUTO_INCREMENT PRIMARY KEY,
                        nombre      VARCHAR(100) NOT NULL,
                        id_torneo   INT NOT NULL,
                        id_facultad INT NOT NULL,
                        ci_capitan  VARCHAR(8) NULL,   -- nullable: se asigna después de armar el plantel
                        FOREIGN KEY (id_torneo)   REFERENCES torneo(id_torneo),
                        FOREIGN KEY (id_facultad) REFERENCES facultad(id_facultad),
                        FOREIGN KEY (ci_capitan)  REFERENCES jugador(ci),
                        UNIQUE (id_torneo, nombre),
                        UNIQUE (id_equipo, id_torneo)  -- permite FK compuesta desde el plantel
);

CREATE TABLE equipo_jugador_torneo (
                                       id_equipo       INT        NOT NULL,
                                       ci_jugador      VARCHAR(8) NOT NULL,
                                       id_torneo       INT        NOT NULL,
                                       numero_camiseta TINYINT    NOT NULL,
                                       PRIMARY KEY (id_equipo, ci_jugador, id_torneo),
                                       FOREIGN KEY (id_equipo, id_torneo) REFERENCES equipo(id_equipo, id_torneo),
                                       FOREIGN KEY (ci_jugador) REFERENCES jugador(ci),
                                       UNIQUE (ci_jugador, id_torneo),      -- un solo equipo por edición
                                       UNIQUE (id_equipo, ci_jugador),      -- referenciable desde la planilla
                                       UNIQUE (id_equipo, numero_camiseta),
                                       CHECK (numero_camiseta BETWEEN 1 AND 99)
);

-- ============ PARTIDOS ============
CREATE TABLE partido (
                         id_partido          INT AUTO_INCREMENT PRIMARY KEY,
                         id_torneo           INT         NOT NULL,
                         numero_fecha        INT         NOT NULL,
                         id_equipo_local     INT         NOT NULL,
                         id_equipo_visitante INT         NOT NULL,
                         dia                 DATE        NOT NULL,
                         id_turno            INT         NOT NULL,
                         nombre_cancha       VARCHAR(50) NOT NULL,
                         id_complejo         INT         NOT NULL,
                         estado              ENUM('programado','jugado','postergado','cancelado')
                                                         NOT NULL DEFAULT 'programado',
                         fecha_hora_jugado   DATETIME NULL,   -- para la regla de las 48 h
                         FOREIGN KEY (id_torneo, numero_fecha) REFERENCES fecha_torneo(id_torneo, numero_fecha),
                         FOREIGN KEY (id_equipo_local,     id_torneo) REFERENCES equipo(id_equipo, id_torneo),
                         FOREIGN KEY (id_equipo_visitante, id_torneo) REFERENCES equipo(id_equipo, id_torneo),
                         FOREIGN KEY (id_turno) REFERENCES turno(id_turno),
                         FOREIGN KEY (nombre_cancha, id_complejo) REFERENCES cancha(nombre_cancha, id_complejo),
                         UNIQUE (id_complejo, nombre_cancha, dia, id_turno),   -- cancha ocupada
                         CHECK (id_equipo_local <> id_equipo_visitante),
                         CHECK ((estado = 'jugado' AND fecha_hora_jugado IS NOT NULL)
                             OR (estado <> 'jugado' AND fecha_hora_jugado IS NULL))
);

-- ============ PLANILLA, GOLES Y TARJETAS ============
CREATE TABLE planilla_partido (
                                  id_partido INT        NOT NULL,
                                  ci_jugador VARCHAR(8) NOT NULL,
                                  id_equipo  INT        NOT NULL,
                                  PRIMARY KEY (id_partido, ci_jugador),
                                  FOREIGN KEY (id_partido) REFERENCES partido(id_partido),
                                  FOREIGN KEY (id_equipo, ci_jugador)
                                      REFERENCES equipo_jugador_torneo(id_equipo, ci_jugador)  -- debe estar en el plantel
);

CREATE TABLE gol (
                     id_gol     INT AUTO_INCREMENT PRIMARY KEY,
                     id_partido INT        NOT NULL,
                     ci_jugador VARCHAR(8) NOT NULL,
                     minuto     TINYINT    NOT NULL,
                     autogol    BOOLEAN    NOT NULL DEFAULT FALSE,
                     FOREIGN KEY (id_partido, ci_jugador)
                         REFERENCES planilla_partido(id_partido, ci_jugador),     -- debe figurar en planilla
                     CHECK (minuto BETWEEN 0 AND 60)
);

CREATE TABLE tarjeta (
                         id_tarjeta INT AUTO_INCREMENT PRIMARY KEY,
                         id_partido INT        NOT NULL,
                         ci_jugador VARCHAR(8) NOT NULL,
                         minuto     TINYINT    NOT NULL,
                         color      ENUM('amarilla','roja') NOT NULL,
                         FOREIGN KEY (id_partido, ci_jugador)
                             REFERENCES planilla_partido(id_partido, ci_jugador),
                         CHECK (minuto BETWEEN 0 AND 60)
);

-- ============ SANCIONES ============
CREATE TABLE sancion_jugador (
                                 id_sancion          INT AUTO_INCREMENT PRIMARY KEY,
                                 ci_jugador          VARCHAR(8) NOT NULL,
                                 id_torneo           INT        NOT NULL,
                                 motivo              ENUM('roja','acumulacion_amarillas','disciplinaria') NOT NULL,
                                 numero_fecha_inicio INT        NOT NULL,
                                 cantidad_fechas     INT        NOT NULL,
                                 id_tarjeta_origen   INT NULL,   -- evita duplicar la sanción automática
                                 FOREIGN KEY (ci_jugador) REFERENCES jugador(ci),
                                 FOREIGN KEY (id_torneo)  REFERENCES torneo(id_torneo),
                                 FOREIGN KEY (id_tarjeta_origen) REFERENCES tarjeta(id_tarjeta),
                                 UNIQUE (id_tarjeta_origen),
                                 CHECK (numero_fecha_inicio >= 1),
                                 CHECK (cantidad_fechas >= 1)
);

INSERT INTO turno (hora_inicio, hora_fin) VALUES
                                              ('18:00','19:00'),('19:00','20:00'),('20:00','21:00'),
                                              ('21:00','22:00'),('22:00','23:00');

USE torneo_futbol5;

-- Los 5 turnos (18:00 a 23:00) ya se insertan en 01_schema.sql

-- ============ FACULTADES ============
INSERT INTO facultad (nombre) VALUES
                                  ('Ciencias Humanas'),
                                  ('Ciencias Empresariales'),
                                  ('Derecho'),
                                  ('Ingeniería y Tecnologías'),
                                  ('Psicología'),
                                  ('Ciencias de la Salud'),
                                  ('Artes y Diseño');

-- ============ COMPLEJOS ============
INSERT INTO complejo (nombre, direccion, departamento) VALUES
                                                           ('Complejo Campus UCU',    'Av. 8 de Octubre 2738',   'Montevideo'),
                                                           ('Fútbol 5 Pocitos',       'Bulevar Artigas 1450',    'Montevideo'),
                                                           ('Complejo Carrasco Indoor','Av. Italia 5620',        'Montevideo'),
                                                           ('Arena Ciudad de la Costa','Av. Giannattasio km 20', 'Canelones');

-- ============ CANCHAS ============
-- (el id_complejo coincide con el orden de los INSERT anteriores: 1 a 4)
INSERT INTO cancha (nombre_cancha, id_complejo, superficie, techada) VALUES
                                                                         ('Cancha 1', 1, 'sintetico', FALSE),
                                                                         ('Cancha 2', 1, 'sintetico', FALSE),
                                                                         ('Cancha 1', 2, 'sintetico', TRUE),
                                                                         ('Cancha 2', 2, 'parquet',   TRUE),
                                                                         ('Cancha A', 3, 'parquet',   TRUE),
                                                                         ('Cancha B', 3, 'parquet',   TRUE),
                                                                         ('Cancha 1', 4, 'sintetico', FALSE),
                                                                         ('Cancha 2', 4, 'sintetico', FALSE);

-- ============ USUARIOS DE LA APP ============
-- Contraseñas (hash bcrypt, costo 12):
--   admin@ucu.edu.uy       -> Admin2026!
--   planillero@ucu.edu.uy  -> Planillero2026!

INSERT INTO login (correo, contrasena, rol) VALUES
                                                ('admin@ucu.edu.uy',
                                                 '$2b$12$8mCcrrFQrzBBfLK/moXBWe.y6IC7PMNwLNJR9HbE8MMGMGbxeSO6q',
                                                 'administrador'),
                                                ('planillero@ucu.edu.uy',
                                                 '$2b$12$LyIiOaJo1hQm47PVmRQ9/OeKiNlndcWp67ITQ/Fw44iiw3VmFqMey',
                                                 'planillero');