-- Turnos
INSERT INTO turno (hora_inicio, hora_fin) VALUES
                                              ('18:00','19:00'),('19:00','20:00'),('20:00','21:00'),
                                              ('21:00','22:00'),('22:00','23:00');

USE torneo_futbol5;

-- Los 5 turnos (18:00 a 23:00) ya se insertan en 01_schema.sql

-- Insert por facultad
INSERT INTO facultad (nombre) VALUES
                                  ('Ciencias Humanas'),
                                  ('Ciencias Empresariales'),
                                  ('Derecho'),
                                  ('Ingeniería y Tecnologías'),
                                  ('Psicología'),
                                  ('Ciencias de la Salud'),
                                  ('Artes y Diseño');

-- Insert por complejo
INSERT INTO complejo (nombre, direccion, departamento) VALUES
                                                           ('Complejo Campus UCU',    'Av. 8 de Octubre 2738',   'Montevideo'),
                                                           ('Fútbol 5 Pocitos',       'Bulevar Artigas 1450',    'Montevideo'),
                                                           ('Complejo Carrasco Indoor','Av. Italia 5620',        'Montevideo'),
                                                           ('Arena Ciudad de la Costa','Av. Giannattasio km 20', 'Canelones');

-- Insert por cancha
INSERT INTO cancha (nombre_cancha, id_complejo, superficie, techada) VALUES
                                                                         ('Cancha 1', 1, 'sintetico', FALSE),
                                                                         ('Cancha 2', 1, 'sintetico', FALSE),
                                                                         ('Cancha 1', 2, 'sintetico', TRUE),
                                                                         ('Cancha 2', 2, 'parquet',   TRUE),
                                                                         ('Cancha A', 3, 'parquet',   TRUE),
                                                                         ('Cancha B', 3, 'parquet',   TRUE),
                                                                         ('Cancha 1', 4, 'sintetico', FALSE),
                                                                         ('Cancha 2', 4, 'sintetico', FALSE);

-- Usuarios 
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