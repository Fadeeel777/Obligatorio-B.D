USE torneo_futbol5;

-- =====================================================================
-- Casos que deben fallar: muestran que los triggers y checks funcionan.
-- Se corre después de 07, con --force para que siga después de cada error:
--   mysql -u root -p --force < "08 - Casos que deben fallar.sql"
-- Cada sentencia tiene que tirar el error indicado en el comentario.
-- Todo va dentro de una transacción con ROLLBACK: no deja cambios.
-- =====================================================================

START TRANSACTION;

-- Simulamos que el planillero carga el partido 16 (Ingeniería vs Derecho,
-- fecha 4) el 3/11 a las 21:10. Esto SÍ funciona.
SET TIMESTAMP = UNIX_TIMESTAMP('2026-11-03 21:10:00');
CALL sp_marcar_partido_jugado(16);
CALL sp_agregar_a_planilla(16, '4810235');   -- Santiago Pereira: OK

-- 1. Suspendido por 3 amarillas -> "El jugador esta suspendido en esta fecha..."
CALL sp_agregar_a_planilla(16, '5023147');
-- 2. Suspendido por roja
CALL sp_agregar_a_planilla(16, '5378124');
-- 3. Suspendido por sanción disciplinaria
CALL sp_agregar_a_planilla(16, '4765432');
-- 4. Jugador que no es de ninguno de los dos equipos -> "El jugador no integra..."
CALL sp_agregar_a_planilla(16, '5523458');
-- 5. Gol de alguien que no está en la planilla -> "Solo pueden convertir goles..."
CALL sp_registrar_gol(16, '4932571', 10, FALSE);
-- 6. Tercera amarilla en el mismo partido (las dos primeras SÍ entran)
CALL sp_registrar_tarjeta(16, '4810235', 10, 'amarilla');
CALL sp_registrar_tarjeta(16, '4810235', 20, 'amarilla');
CALL sp_registrar_tarjeta(16, '4810235', 30, 'amarilla');   -- falla
-- 7. Minuto fuera de rango -> "El minuto debe estar entre 0 y 60"
CALL sp_registrar_gol(16, '4810235', 75, FALSE);

-- 8. Marcar como jugado un partido que todavía no se jugó (17/11)
CALL sp_marcar_partido_jugado(19);
-- 9. Cancha ocupada: mover el partido 18 a la cancha/día/turno del 16
UPDATE partido SET dia = '2026-11-03', id_turno = 3, nombre_cancha = 'Celeste', id_complejo = 1
 WHERE id_partido = 18;
-- 10. Día fuera del rango de la fecha 4
UPDATE partido SET dia = '2026-11-20' WHERE id_partido = 18;
-- 11. Rival repetido en la edición (Ingeniería ya jugó con Humanas)
INSERT INTO partido (id_torneo, numero_fecha, id_equipo_local, id_equipo_visitante,
                     dia, id_turno, nombre_cancha, id_complejo)
VALUES (2, 5, 10, 5, '2026-11-19', 1, 'Blanca', 1);
-- 12. Modificar un partido ya jugado
UPDATE partido SET id_turno = 5 WHERE id_partido = 7;
-- 13. Borrar un partido jugado
DELETE FROM partido WHERE id_partido = 1;

-- 14. Inscribir un equipo en un torneo que ya está en curso
INSERT INTO equipo (nombre, id_torneo, id_facultad) VALUES ('Nuevo FC', 2, 7);
-- 15. Jugador de otra facultad en el plantel (Santiago es de Ingeniería, el equipo es de Artes)
INSERT INTO equipo_jugador_torneo (id_equipo, ci_jugador, id_torneo, numero_camiseta)
VALUES (11, '4810235', 3, 9);
-- 16. Iniciar un torneo con un solo equipo (y con un plantel de 2 jugadores)
CALL sp_cambiar_estado_torneo(3, 'en_curso');
-- 17. Finalizar un torneo con partidos programados o postergados
CALL sp_cambiar_estado_torneo(2, 'finalizado');
-- 18. Transición de estado inválida (finalizado -> en_curso)
CALL sp_cambiar_estado_torneo(1, 'en_curso');
-- 19. Borrar un torneo que no está en inscripción
DELETE FROM torneo WHERE id_torneo = 1;

-- 20. Contraseña en texto plano -> "La contrasena debe guardarse como hash bcrypt"
INSERT INTO login (correo, contrasena, rol) VALUES ('nuevo@ucu.edu.uy', '1234', 'planillero');
-- 21. CI con letras (CHECK de la tabla)
INSERT INTO jugador (ci, nombre, apellido, email, fecha_nacimiento, id_facultad, tipo)
VALUES ('12ab567', 'Test', 'Test', 'test@correo.ucu.edu.uy', '2000-01-01', 1, 'grado');

ROLLBACK;
SET TIMESTAMP = DEFAULT;

-- 22. Corregir un partido después de las 48 horas (partido 7, del 1/9)
INSERT INTO gol (id_partido, ci_jugador, minuto, autogol) VALUES (7, '4810235', 59, 0);
