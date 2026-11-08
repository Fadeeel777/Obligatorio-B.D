USE torneo_futbol5;


-- Datos de prueba
-- Se corre DESPUÉS de 01, 02, 04, 05 y 06: todo pasa por los triggers y
-- procedimientos, así que los datos cumplen las mismas reglas que la app.
--
-- Escenario:
--   Torneo 1 (2026 S1): 4 equipos, 3 fechas, todo jugado, FINALIZADO.
--   Torneo 2 (2026 S2): 6 equipos, 5 fechas, EN CURSO.
--       Fechas 1-3 jugadas (un partido cancelado).
--       Fecha 4: un partido ya pasó pero falta cargarlo (para probar al
--                planillero), uno postergado y uno programado.
--       Fecha 5: programada.
--       Para la fecha 4 hay suspendidos de los tres motivos.
--   Torneo 3 (2027 S1): en INSCRIPCIÓN, con un equipo incompleto.
--
-- Por qué SET TIMESTAMP:
--   Los triggers solo dejan marcar un partido como jugado si su turno ya
--   pasó, y cargar planilla/goles/tarjetas dentro de las 48 h siguientes.
--   SET TIMESTAMP cambia el NOW() de esta sesión (y de nada más), así que
--   simulamos que el planillero cargó cada partido al terminar.
--   Las reglas se validan igual. Al final se vuelve a la hora real.




-- Ayuda temporal: pone en la planilla a todo el plantel de los dos
-- equipos, salvo suspendidos y suplentes (camiseta >= 20).
-- Se borra al final del archivo.

DELIMITER $$
DROP PROCEDURE IF EXISTS tmp_cargar_planilla$$
CREATE PROCEDURE tmp_cargar_planilla(IN p_id_partido INT)
BEGIN
  INSERT INTO planilla_partido (id_partido, ci_jugador, id_equipo)
  SELECT p.id_partido, ejt.ci_jugador, ejt.id_equipo
    FROM partido p
    JOIN equipo_jugador_torneo ejt
      ON ejt.id_torneo = p.id_torneo
     AND ejt.id_equipo IN (p.id_equipo_local, p.id_equipo_visitante)
   WHERE p.id_partido = p_id_partido
     AND ejt.numero_camiseta < 20
     AND fn_sancionado(ejt.ci_jugador, p.id_torneo, p.numero_fecha) = 0;
END$$
DELIMITER ;


-- ---------------------------------------------------------------------
-- Jugadores
-- ---------------------------------------------------------------------
INSERT INTO jugador (ci, nombre, apellido, email, fecha_nacimiento, id_facultad, tipo) VALUES
  -- Ingeniería y Tecnologías (4)
  ('4810235', 'Santiago',   'Pereira',   'santiago.pereira@correo.ucu.edu.uy',   '2002-03-14', 4, 'grado'),
  ('5023147', 'Martín',     'Rodríguez', 'martin.rodriguez@correo.ucu.edu.uy',   '2003-07-22', 4, 'grado'),
  ('5136982', 'Nicolás',    'Fernández', 'nicolas.fernandez@correo.ucu.edu.uy',  '2004-01-09', 4, 'grado'),
  ('4932571', 'Joaquín',    'Silva',     'joaquin.silva@correo.ucu.edu.uy',      '1998-11-30', 4, 'posgrado'),
  ('3456120', 'Diego',      'Martínez',  'diego.martinez@ucu.edu.uy',            '1985-05-18', 4, 'docente'),
  ('5247813', 'Facundo',    'González',  'facundo.gonzalez@correo.ucu.edu.uy',   '2003-09-02', 4, 'grado'),
  ('5361094', 'Bruno',      'Sosa',      'bruno.sosa@correo.ucu.edu.uy',         '2005-02-27', 4, 'grado'),
  ('5745670', 'Renzo',      'Pintos',    'renzo.pintos@correo.ucu.edu.uy',       '2005-06-11', 4, 'grado'),
  -- Ciencias Empresariales (2)
  ('5012384', 'Agustín',    'López',     'agustin.lopez@correo.ucu.edu.uy',      '2002-12-05', 2, 'grado'),
  ('5129476', 'Federico',   'Díaz',      'federico.diaz@correo.ucu.edu.uy',      '2003-04-17', 2, 'grado'),
  ('4876213', 'Matías',     'Suárez',    'matias.suarez@correo.ucu.edu.uy',      '1997-08-08', 2, 'posgrado'),
  ('5233810', 'Gonzalo',    'Romero',    'gonzalo.romero@correo.ucu.edu.uy',     '2004-10-21', 2, 'grado'),
  ('3987456', 'Pablo',      'Castro',    'pablo.castro@ucu.edu.uy',              '1990-01-13', 2, 'funcionario'),
  ('5345671', 'Emiliano',   'Núñez',     'emiliano.nunez@correo.ucu.edu.uy',     '2004-06-29', 2, 'grado'),
  ('5098312', 'Tomás',      'Ramírez',   'tomas.ramirez@correo.ucu.edu.uy',      '2003-03-03', 2, 'grado'),
  -- Derecho (3)
  ('5156723', 'Lucas',      'Méndez',    'lucas.mendez@correo.ucu.edu.uy',       '2002-08-19', 3, 'grado'),
  ('5267390', 'Rodrigo',    'Álvarez',   'rodrigo.alvarez@correo.ucu.edu.uy',    '2003-12-01', 3, 'grado'),
  ('4765432', 'Andrés',     'Gómez',     'andres.gomez@correo.ucu.edu.uy',       '1996-04-25', 3, 'posgrado'),
  ('2987654', 'Gustavo',    'Benítez',   'gustavo.benitez@ucu.edu.uy',           '1979-09-14', 3, 'docente'),
  ('5378124', 'Ignacio',    'Acosta',    'ignacio.acosta@correo.ucu.edu.uy',     '2004-02-16', 3, 'grado'),
  ('5189046', 'Felipe',     'Torres',    'felipe.torres@correo.ucu.edu.uy',      '2003-05-07', 3, 'grado'),
  ('5290157', 'Manuel',     'Medina',    'manuel.medina@correo.ucu.edu.uy',      '2005-07-23', 3, 'grado'),
  -- Ciencias de la Salud (6)
  ('5401236', 'Sebastián',  'Vázquez',   'sebastian.vazquez@correo.ucu.edu.uy',  '2002-10-10', 6, 'grado'),
  ('5112347', 'Germán',     'Cabrera',   'german.cabrera@correo.ucu.edu.uy',     '2003-01-28', 6, 'grado'),
  ('4654321', 'Leandro',    'Ríos',      'leandro.rios@correo.ucu.edu.uy',       '1995-06-06', 6, 'posgrado'),
  ('5223458', 'Maximiliano','Herrera',   'maximiliano.herrera@correo.ucu.edu.uy','2004-03-31', 6, 'grado'),
  ('3678901', 'Hernán',     'Olivera',   'hernan.olivera@ucu.edu.uy',            '1988-12-12', 6, 'funcionario'),
  ('3789012', 'Marcelo',    'Ferreira',  'marcelo.ferreira@ucu.edu.uy',          '1982-02-20', 6, 'docente'),
  ('5334569', 'Valentín',   'Morales',   'valentin.morales@correo.ucu.edu.uy',   '2005-09-15', 6, 'grado'),
  -- Psicología (5)
  ('5445670', 'Franco',     'Giménez',   'franco.gimenez@correo.ucu.edu.uy',     '2003-11-04', 5, 'grado'),
  ('5156781', 'Alejandro',  'Ortiz',     'alejandro.ortiz@correo.ucu.edu.uy',    '2002-07-12', 5, 'grado'),
  ('4543210', 'Ezequiel',   'Rojas',     'ezequiel.rojas@correo.ucu.edu.uy',     '1997-03-26', 5, 'posgrado'),
  ('5267892', 'Mauricio',   'Molina',    'mauricio.molina@correo.ucu.edu.uy',    '2004-08-30', 5, 'grado'),
  ('5378903', 'Cristian',   'Pérez',     'cristian.perez@correo.ucu.edu.uy',     '2004-12-18', 5, 'grado'),
  ('3890123', 'Fernando',   'Silveira',  'fernando.silveira@ucu.edu.uy',         '1987-10-02', 5, 'funcionario'),
  -- Ciencias Humanas (1)
  ('5489014', 'Juan',       'Ibarra',    'juan.ibarra@correo.ucu.edu.uy',        '2003-06-24', 1, 'grado'),
  ('5190125', 'Kevin',      'De León',   'kevin.deleon@correo.ucu.edu.uy',       '2004-04-09', 1, 'grado'),
  ('5201236', 'Thiago',     'Correa',    'thiago.correa@correo.ucu.edu.uy',      '2005-01-19', 1, 'grado'),
  ('4432109', 'Damián',     'Machado',   'damian.machado@correo.ucu.edu.uy',     '1996-09-27', 1, 'posgrado'),
  ('3123456', 'Ricardo',    'Viera',     'ricardo.viera@ucu.edu.uy',             '1975-11-08', 1, 'docente'),
  ('5312347', 'Mateo',      'Cardozo',   'mateo.cardozo@correo.ucu.edu.uy',      '2003-02-14', 1, 'grado'),
  -- Artes y Diseño (7)
  ('5523458', 'Lautaro',    'Rivero',    'lautaro.rivero@correo.ucu.edu.uy',     '2004-05-05', 7, 'grado'),
  ('5634569', 'Camilo',     'Bentancur', 'camilo.bentancur@correo.ucu.edu.uy',   '2005-08-21', 7, 'grado');



-- TORNEO 1 - 2026 Semestre 1 (termina finalizado)

INSERT INTO torneo (id_torneo, nombre, anio, semestre, fecha_inicio, fecha_fin) VALUES
  (1, 'Copa UCU 2026 - Semestre 1', 2026, 1, '2026-04-01', '2026-06-30');

INSERT INTO fecha_torneo (id_torneo, numero_fecha, fecha_desde, fecha_hasta) VALUES
  (1, 1, '2026-04-06', '2026-04-12'),
  (1, 2, '2026-04-20', '2026-04-26'),
  (1, 3, '2026-05-04', '2026-05-10');

INSERT INTO equipo (id_equipo, nombre, id_torneo, id_facultad, ci_capitan) VALUES
  (1, 'Ingeniería FC',        1, 4, '4810235'),
  (2, 'Empresariales United', 1, 2, '5012384'),
  (3, 'Derecho Unido',        1, 3, '5156723'),
  (4, 'Salud Atlético',       1, 6, '5401236');

INSERT INTO equipo_jugador_torneo (id_equipo, ci_jugador, id_torneo, numero_camiseta) VALUES
  (1, '4810235', 1, 10), (1, '5023147', 1, 5), (1, '5136982', 1, 4),
  (1, '4932571', 1, 9),  (1, '3456120', 1, 1), (1, '5247813', 1, 7),
  (2, '5012384', 1, 10), (2, '5129476', 1, 4), (2, '4876213', 1, 9),
  (2, '5233810', 1, 7),  (2, '3987456', 1, 1), (2, '5345671', 1, 5),
  (3, '5156723', 1, 9),  (3, '5267390', 1, 7), (3, '4765432', 1, 4),
  (3, '2987654', 1, 1),  (3, '5378124', 1, 10),(3, '5189046', 1, 5),
  (4, '5401236', 1, 10), (4, '5112347', 1, 5), (4, '4654321', 1, 9),
  (4, '5223458', 1, 7),  (4, '3678901', 1, 1), (4, '3789012', 1, 4);

CALL sp_cambiar_estado_torneo(1, 'en_curso');

-- Turnos: 1=18h 2=19h 3=20h 4=21h 5=22h
INSERT INTO partido (id_partido, id_torneo, numero_fecha, id_equipo_local, id_equipo_visitante,
                     dia, id_turno, nombre_cancha, id_complejo) VALUES
  (1, 1, 1, 1, 2, '2026-04-07', 2, 'Celeste', 1),
  (2, 1, 1, 3, 4, '2026-04-07', 3, 'Celeste', 1),
  (3, 1, 2, 1, 3, '2026-04-21', 2, 'Roja',    2),
  (4, 1, 2, 2, 4, '2026-04-22', 4, 'Verde',   3),
  (5, 1, 3, 1, 4, '2026-05-05', 3, 'Celeste', 1),
  (6, 1, 3, 2, 3, '2026-05-06', 2, 'Negra',   4);

-- Partido 1: Ingeniería 2-1 Empresariales
SET TIMESTAMP = UNIX_TIMESTAMP('2026-04-07 20:10:00');
CALL sp_marcar_partido_jugado(1);
CALL tmp_cargar_planilla(1);
INSERT INTO gol (id_partido, ci_jugador, minuto, autogol) VALUES
  (1, '4810235', 12, 0), (1, '4932571', 35, 0), (1, '5012384', 40, 0);
INSERT INTO tarjeta (id_partido, ci_jugador, minuto, color) VALUES
  (1, '5129476', 28, 'amarilla');

-- Partido 2: Derecho 0-0 Salud. Roja a Rodrigo Álvarez: no juega la fecha 2
SET TIMESTAMP = UNIX_TIMESTAMP('2026-04-07 21:10:00');
CALL sp_marcar_partido_jugado(2);
CALL tmp_cargar_planilla(2);
INSERT INTO tarjeta (id_partido, ci_jugador, minuto, color) VALUES
  (2, '2987654', 22, 'amarilla'),
  (2, '5267390', 50, 'roja');

-- Partido 3: Ingeniería 3-3 Derecho (un autogol de Nicolás Fernández)
SET TIMESTAMP = UNIX_TIMESTAMP('2026-04-21 20:10:00');
CALL sp_marcar_partido_jugado(3);
CALL tmp_cargar_planilla(3);              -- Rodrigo Álvarez queda afuera (suspendido)
INSERT INTO gol (id_partido, ci_jugador, minuto, autogol) VALUES
  (3, '4810235',  5, 0), (3, '5156723', 10, 0), (3, '4810235', 22, 0),
  (3, '5378124', 30, 0), (3, '5023147', 48, 0), (3, '5136982', 55, 1);

-- Partido 4: Empresariales 1-2 Salud
SET TIMESTAMP = UNIX_TIMESTAMP('2026-04-22 22:10:00');
CALL sp_marcar_partido_jugado(4);
CALL tmp_cargar_planilla(4);
INSERT INTO gol (id_partido, ci_jugador, minuto, autogol) VALUES
  (4, '4876213', 15, 0), (4, '5401236', 20, 0), (4, '5112347', 44, 0);
INSERT INTO tarjeta (id_partido, ci_jugador, minuto, color) VALUES
  (4, '3987456', 31, 'amarilla'), (4, '4654321', 47, 'amarilla');

-- Partido 5: Ingeniería 1-0 Salud
SET TIMESTAMP = UNIX_TIMESTAMP('2026-05-05 21:10:00');
CALL sp_marcar_partido_jugado(5);
CALL tmp_cargar_planilla(5);
INSERT INTO gol (id_partido, ci_jugador, minuto, autogol) VALUES
  (5, '4932571', 33, 0);
INSERT INTO tarjeta (id_partido, ci_jugador, minuto, color) VALUES
  (5, '5247813', 40, 'amarilla');

-- Partido 6: Empresariales 2-2 Derecho
SET TIMESTAMP = UNIX_TIMESTAMP('2026-05-06 20:10:00');
CALL sp_marcar_partido_jugado(6);
CALL tmp_cargar_planilla(6);
INSERT INTO gol (id_partido, ci_jugador, minuto, autogol) VALUES
  (6, '5012384',  8, 0), (6, '5156723', 18, 0),
  (6, '5156723', 41, 0), (6, '5233810', 52, 0);

CALL sp_cambiar_estado_torneo(1, 'finalizado');



-- TORNEO 2 - 2026 Semestre 2 (queda en curso)

INSERT INTO torneo (id_torneo, nombre, anio, semestre, fecha_inicio, fecha_fin) VALUES
  (2, 'Copa UCU 2026 - Semestre 2', 2026, 2, '2026-08-17', '2026-11-30');

INSERT INTO fecha_torneo (id_torneo, numero_fecha, fecha_desde, fecha_hasta) VALUES
  (2, 1, '2026-08-31', '2026-09-06'),
  (2, 2, '2026-09-14', '2026-09-20'),
  (2, 3, '2026-10-05', '2026-10-11'),
  (2, 4, '2026-11-02', '2026-11-08'),
  (2, 5, '2026-11-16', '2026-11-22');

INSERT INTO equipo (id_equipo, nombre, id_torneo, id_facultad, ci_capitan) VALUES
  (5,  'Ingeniería FC',        2, 4, '4810235'),
  (6,  'Empresariales United', 2, 2, '5012384'),
  (7,  'Derecho Unido',        2, 3, '5156723'),
  (8,  'Salud Atlético',       2, 6, '5401236'),
  (9,  'Psico Juniors',        2, 5, '5445670'),
  (10, 'Humanas FC',           2, 1, '5489014');

-- Bruno Sosa (Ingeniería) y Manuel Medina (Derecho) llevan la 21: son
-- suplentes que nunca entran a la planilla (salen en v_jugadores_sin_planilla).
INSERT INTO equipo_jugador_torneo (id_equipo, ci_jugador, id_torneo, numero_camiseta) VALUES
  (5,  '4810235', 2, 10), (5,  '5023147', 2, 5),  (5,  '5136982', 2, 4),
  (5,  '4932571', 2, 9),  (5,  '3456120', 2, 1),  (5,  '5247813', 2, 7),
  (5,  '5361094', 2, 21),
  (6,  '5012384', 2, 10), (6,  '5129476', 2, 4),  (6,  '4876213', 2, 9),
  (6,  '5233810', 2, 7),  (6,  '3987456', 2, 1),  (6,  '5345671', 2, 5),
  (6,  '5098312', 2, 11),
  (7,  '5156723', 2, 9),  (7,  '5267390', 2, 7),  (7,  '4765432', 2, 4),
  (7,  '2987654', 2, 1),  (7,  '5378124', 2, 10), (7,  '5189046', 2, 5),
  (7,  '5290157', 2, 21),
  (8,  '5401236', 2, 10), (8,  '5112347', 2, 5),  (8,  '4654321', 2, 9),
  (8,  '5223458', 2, 7),  (8,  '3678901', 2, 1),  (8,  '3789012', 2, 4),
  (8,  '5334569', 2, 11),
  (9,  '5445670', 2, 10), (9,  '5156781', 2, 7),  (9,  '4543210', 2, 9),
  (9,  '5267892', 2, 5),  (9,  '5378903', 2, 11), (9,  '3890123', 2, 1),
  (10, '5489014', 2, 10), (10, '5190125', 2, 9),  (10, '5201236', 2, 7),
  (10, '4432109', 2, 4),  (10, '3123456', 2, 1),  (10, '5312347', 2, 5);

CALL sp_cambiar_estado_torneo(2, 'en_curso');

INSERT INTO partido (id_partido, id_torneo, numero_fecha, id_equipo_local, id_equipo_visitante,
                     dia, id_turno, nombre_cancha, id_complejo) VALUES
  -- Fecha 1
  (7,  2, 1, 5,  10, '2026-09-01', 1, 'Celeste',  1),
  (8,  2, 1, 6,  9,  '2026-09-01', 2, 'Celeste',  1),
  (9,  2, 1, 7,  8,  '2026-09-02', 3, 'Roja',     2),
  -- Fecha 2
  (10, 2, 2, 5,  9,  '2026-09-15', 2, 'Verde',    3),
  (11, 2, 2, 10, 8,  '2026-09-15', 3, 'Verde',    3),
  (12, 2, 2, 6,  7,  '2026-09-16', 4, 'Negra',    4),
  -- Fecha 3
  (13, 2, 3, 5,  8,  '2026-10-06', 2, 'Celeste',  1),
  (14, 2, 3, 9,  7,  '2026-10-07', 3, 'Azul',     2),
  (15, 2, 3, 10, 6,  '2026-10-07', 5, 'Amarilla', 3),
  -- Fecha 4
  (16, 2, 4, 5,  7,  '2026-11-03', 3, 'Celeste',  1),
  (17, 2, 4, 8,  6,  '2026-11-04', 2, 'Roja',     2),
  (18, 2, 4, 9,  10, '2026-11-06', 4, 'Verde',    3),
  -- Fecha 5
  (19, 2, 5, 5,  6,  '2026-11-17', 2, 'Celeste',  1),
  (20, 2, 5, 7,  10, '2026-11-17', 3, 'Celeste',  1),
  (21, 2, 5, 8,  9,  '2026-11-18', 1, 'Negra',    4);

-- ----- Fecha 1 -----

-- Partido 7: Ingeniería 3-1 Humanas
SET TIMESTAMP = UNIX_TIMESTAMP('2026-09-01 19:10:00');
CALL sp_marcar_partido_jugado(7);
CALL tmp_cargar_planilla(7);
INSERT INTO gol (id_partido, ci_jugador, minuto, autogol) VALUES
  (7, '4810235',  7, 0), (7, '4932571', 25, 0),
  (7, '5190125', 38, 0), (7, '5247813', 50, 0);
INSERT INTO tarjeta (id_partido, ci_jugador, minuto, color) VALUES
  (7, '5023147', 30, 'amarilla'),        -- Martín Rodríguez: 1ra amarilla
  (7, '4432109', 44, 'amarilla');

-- Partido 8: Empresariales 0-2 Psicología
SET TIMESTAMP = UNIX_TIMESTAMP('2026-09-01 20:10:00');
CALL sp_marcar_partido_jugado(8);
CALL tmp_cargar_planilla(8);
INSERT INTO gol (id_partido, ci_jugador, minuto, autogol) VALUES
  (8, '5445670', 14, 0), (8, '4543210', 47, 0);
INSERT INTO tarjeta (id_partido, ci_jugador, minuto, color) VALUES
  (8, '5233810', 19, 'amarilla'), (8, '5267892', 36, 'amarilla');

-- Partido 9: Derecho 2-2 Salud
SET TIMESTAMP = UNIX_TIMESTAMP('2026-09-02 21:10:00');
CALL sp_marcar_partido_jugado(9);
CALL tmp_cargar_planilla(9);
INSERT INTO gol (id_partido, ci_jugador, minuto, autogol) VALUES
  (9, '5156723',  9, 0), (9, '5401236', 21, 0),
  (9, '5189046', 33, 0), (9, '5334569', 58, 0);
INSERT INTO tarjeta (id_partido, ci_jugador, minuto, color) VALUES
  (9, '3678901', 26, 'amarilla'), (9, '5189046', 40, 'amarilla');

-- ----- Fecha 2 -----

-- Partido 10: Ingeniería 1-1 Psicología
SET TIMESTAMP = UNIX_TIMESTAMP('2026-09-15 20:10:00');
CALL sp_marcar_partido_jugado(10);
CALL tmp_cargar_planilla(10);
INSERT INTO gol (id_partido, ci_jugador, minuto, autogol) VALUES
  (10, '5378903', 12, 0), (10, '5136982', 40, 0);
INSERT INTO tarjeta (id_partido, ci_jugador, minuto, color) VALUES
  (10, '5023147', 55, 'amarilla');       -- Martín Rodríguez: 2da amarilla

-- Partido 11: Humanas 1-0 Salud. Germán Cabrera: doble amarilla y roja
SET TIMESTAMP = UNIX_TIMESTAMP('2026-09-15 21:10:00');
CALL sp_marcar_partido_jugado(11);
CALL tmp_cargar_planilla(11);
INSERT INTO gol (id_partido, ci_jugador, minuto, autogol) VALUES
  (11, '5201236', 28, 0);
INSERT INTO tarjeta (id_partido, ci_jugador, minuto, color) VALUES
  (11, '5112347', 10, 'amarilla'),
  (11, '5112347', 35, 'amarilla'),
  (11, '5112347', 35, 'roja');           -- suspendido en la fecha 3

-- Partido 12: Empresariales 2-3 Derecho (autogol de Pablo Castro)
SET TIMESTAMP = UNIX_TIMESTAMP('2026-09-16 22:10:00');
CALL sp_marcar_partido_jugado(12);
CALL tmp_cargar_planilla(12);
INSERT INTO gol (id_partido, ci_jugador, minuto, autogol) VALUES
  (12, '5012384',  5, 0), (12, '5156723', 17, 0), (12, '5156723', 30, 0),
  (12, '5345671', 44, 0), (12, '3987456', 52, 1);

-- ----- Fecha 3 -----

-- Partido 13: Ingeniería 0-1 Salud
SET TIMESTAMP = UNIX_TIMESTAMP('2026-10-06 20:10:00');
CALL sp_marcar_partido_jugado(13);
CALL tmp_cargar_planilla(13);              -- Germán Cabrera queda afuera (suspendido)
INSERT INTO gol (id_partido, ci_jugador, minuto, autogol) VALUES
  (13, '4654321', 39, 0);
INSERT INTO tarjeta (id_partido, ci_jugador, minuto, color) VALUES
  (13, '5023147', 20, 'amarilla'),       -- Martín Rodríguez: 3ra amarilla -> suspendido fecha 4
  (13, '3456120', 48, 'amarilla');

-- Partido 14: Psicología 1-2 Derecho. Roja a Ignacio Acosta
SET TIMESTAMP = UNIX_TIMESTAMP('2026-10-07 21:10:00');
CALL sp_marcar_partido_jugado(14);
CALL tmp_cargar_planilla(14);
INSERT INTO gol (id_partido, ci_jugador, minuto, autogol) VALUES
  (14, '5267390', 11, 0), (14, '5156723', 26, 0), (14, '5445670', 50, 0);
INSERT INTO tarjeta (id_partido, ci_jugador, minuto, color) VALUES
  (14, '5156781', 33, 'amarilla'),
  (14, '5378124', 45, 'roja');           -- suspendido en la fecha 4

-- Partido 15: Humanas vs Empresariales, cancelado (no había árbitro)
SET TIMESTAMP = UNIX_TIMESTAMP('2026-10-07 22:00:00');
UPDATE partido SET estado = 'cancelado' WHERE id_partido = 15;

-- Sanción disciplinaria: Andrés Gómez, fechas 4 y 5
SET TIMESTAMP = UNIX_TIMESTAMP('2026-10-09 12:00:00');
CALL sp_sancion_disciplinaria('4765432', 2, 4, 2);

-- ----- Fecha 4 -----
-- Partido 16 (Ingeniería vs Derecho, 3/11): ya pasó pero sigue 'programado'.
--   Sirve para probar en la app que el planillero lo marque como jugado y
--   cargue la planilla. Tienen que rebotar Martín Rodríguez (amarillas),
--   Ignacio Acosta (roja) y Andrés Gómez (disciplinaria).
-- Partido 17 (Salud vs Empresariales): postergado.
-- Partido 18 (Psicología vs Humanas, 6/11): programado.
UPDATE partido SET estado = 'postergado' WHERE id_partido = 17;

-- Volver a la hora real
SET TIMESTAMP = DEFAULT;



-- TORNEO 3 - 2027 Semestre 1 (en inscripción)
-- Un equipo con solo 2 jugadores, para probar el alta de planteles desde
-- la app. Renzo Pintos (Ingeniería) no está en ningún equipo.

INSERT INTO torneo (id_torneo, nombre, anio, semestre, fecha_inicio, fecha_fin) VALUES
  (3, 'Copa UCU 2027 - Semestre 1', 2027, 1, '2027-03-29', '2027-06-30');

INSERT INTO fecha_torneo (id_torneo, numero_fecha, fecha_desde, fecha_hasta) VALUES
  (3, 1, '2027-04-05', '2027-04-11'),
  (3, 2, '2027-04-19', '2027-04-25');

INSERT INTO equipo (id_equipo, nombre, id_torneo, id_facultad, ci_capitan) VALUES
  (11, 'Artes FC', 3, 7, '5523458');

INSERT INTO equipo_jugador_torneo (id_equipo, ci_jugador, id_torneo, numero_camiseta) VALUES
  (11, '5523458', 3, 10),
  (11, '5634569', 3, 5);


DROP PROCEDURE IF EXISTS tmp_cargar_planilla;
