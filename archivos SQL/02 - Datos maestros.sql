USE torneo_futbol5;

-- Inserts de horas
INSERT INTO turno (hora_inicio, hora_fin) VALUES
 ('18:00','19:00'),('19:00','20:00'),('20:00','21:00'),
 ('21:00','22:00'),('22:00','23:00');

-- Inserts de facultades
INSERT INTO facultad (nombre) VALUES
                                  ('Ciencias Humanas'),
                                  ('Ciencias Empresariales'),
                                  ('Derecho'),
                                  ('Ingeniería y Tecnologías'),
                                  ('Psicología'),
                                  ('Ciencias de la Salud'),
                                  ('Artes y Diseño');

-- Inserts de complejos
INSERT INTO complejo (nombre, direccion, departamento) VALUES
                                                           ('Complejo Campus UCU',    'Av. 8 de Octubre 2738',   'Montevideo'),
                                                           ('Fútbol 5 Pocitos',       'Bulevar Artigas 1450',    'Montevideo'),
                                                           ('Complejo Carrasco Indoor','Av. Italia 5620',        'Montevideo'),
                                                           ('Arena Ciudad de la Costa','Av. Giannattasio km 20', 'Canelones');

-- Inserts de canchas
INSERT INTO cancha (nombre_cancha, id_complejo, superficie, techada) VALUES
 			('Celeste', 1, 'sintetico', FALSE),
 ('Blanca',  1, 'sintetico', FALSE),
 						('Roja',    2, 'sintetico', TRUE),
 ('Azul',    2, 'parquet',   TRUE),
 ('Verde',   3, 'parquet',   TRUE),
 ('Amarilla',3, 'parquet',   TRUE),
 ('Negra',   4, 'sintetico', FALSE),
 ('Naranja', 4, 'sintetico', FALSE);


-- Inserts de usuarios

INSERT INTO login (correo, contrasena, rol) VALUES
                                                ('admin@ucu.edu.uy',
                                                 '$2b$12$8mCcrrFQrzBBfLK/moXBWe.y6IC7PMNwLNJR9HbE8MMGMGbxeSO6q',
                                                 'administrador'),
                                                ('planillero@ucu.edu.uy',
                                                 '$2b$12$LyIiOaJo1hQm47PVmRQ9/OeKiNlndcWp67ITQ/Fw44iiw3VmFqMey',
                                                 'planillero');
