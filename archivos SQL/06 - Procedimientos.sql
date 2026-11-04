
USE torneo_futbol5;

DELIMITER $$

-- Procedimientos del planillero: planilla, goles y tarjetas

-- Marca el partido como jugado (valida que su dia y turno ya pasaron).
DROP PROCEDURE IF EXISTS sp_marcar_partido_jugado$$
CREATE PROCEDURE sp_marcar_partido_jugado(IN p_id_partido INT)
SQL SECURITY DEFINER
BEGIN
  DECLARE v_estado VARCHAR(20) DEFAULT NULL;
  SELECT estado INTO v_estado FROM partido WHERE id_partido = p_id_partido;
  IF v_estado IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El partido no existe';
  END IF;
  IF v_estado = 'jugado' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El partido ya esta marcado como jugado';
  END IF;
  UPDATE partido SET estado = 'jugado', fecha_hora_jugado = NOW()
   WHERE id_partido = p_id_partido;
END$$

-- Agrega un jugador a la planilla, el equipo se deduce de su plantel.
DROP PROCEDURE IF EXISTS sp_agregar_a_planilla$$
CREATE PROCEDURE sp_agregar_a_planilla(IN p_id_partido INT, IN p_ci VARCHAR(8))
SQL SECURITY DEFINER
BEGIN
  DECLARE v_torneo INT DEFAULT NULL;
  DECLARE v_equipo INT DEFAULT NULL;

  SELECT id_torneo INTO v_torneo FROM partido WHERE id_partido = p_id_partido;
  IF v_torneo IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El partido no existe';
  END IF;
  SELECT id_equipo INTO v_equipo FROM equipo_jugador_torneo
   WHERE ci_jugador = p_ci AND id_torneo = v_torneo;
  IF v_equipo IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El jugador no integra ningun plantel de esta edicion';
  END IF;
  IF EXISTS (SELECT 1 FROM planilla_partido WHERE id_partido = p_id_partido AND ci_jugador = p_ci) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El jugador ya figura en la planilla de este partido';
  END IF;
  INSERT INTO planilla_partido (id_partido, ci_jugador, id_equipo)
  VALUES (p_id_partido, p_ci, v_equipo);
END$$

DROP PROCEDURE IF EXISTS sp_quitar_de_planilla$$
CREATE PROCEDURE sp_quitar_de_planilla(IN p_id_partido INT, IN p_ci VARCHAR(8))
SQL SECURITY DEFINER
BEGIN
  DELETE FROM planilla_partido WHERE id_partido = p_id_partido AND ci_jugador = p_ci;
  IF ROW_COUNT() = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El jugador no figura en la planilla de ese partido';
  END IF;
END$$

DROP PROCEDURE IF EXISTS sp_registrar_gol$$
CREATE PROCEDURE sp_registrar_gol(IN p_id_partido INT, IN p_ci VARCHAR(8),
                                  IN p_minuto INT, IN p_autogol BOOLEAN)
SQL SECURITY DEFINER
BEGIN
  IF p_minuto NOT BETWEEN 0 AND 60 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El minuto debe estar entre 0 y 60';
  END IF;
  INSERT INTO gol (id_partido, ci_jugador, minuto, autogol)
  VALUES (p_id_partido, p_ci, p_minuto, COALESCE(p_autogol, FALSE));
  SELECT LAST_INSERT_ID() AS id_gol;
END$$

DROP PROCEDURE IF EXISTS sp_eliminar_gol$$
CREATE PROCEDURE sp_eliminar_gol(IN p_id_gol INT)
SQL SECURITY DEFINER
BEGIN
  DELETE FROM gol WHERE id_gol = p_id_gol;
  IF ROW_COUNT() = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El gol no existe';
  END IF;
END$$

-- Registra la tarjeta; el trigger genera la sancion automatica (roja o 3ra amarilla).
DROP PROCEDURE IF EXISTS sp_registrar_tarjeta$$
CREATE PROCEDURE sp_registrar_tarjeta(IN p_id_partido INT, IN p_ci VARCHAR(8),
                                      IN p_minuto INT, IN p_color VARCHAR(10))
SQL SECURITY DEFINER
BEGIN
  IF p_minuto NOT BETWEEN 0 AND 60 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El minuto debe estar entre 0 y 60';
  END IF;
  IF p_color NOT IN ('amarilla','roja') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El color debe ser amarilla o roja';
  END IF;
  INSERT INTO tarjeta (id_partido, ci_jugador, minuto, color)
  VALUES (p_id_partido, p_ci, p_minuto, p_color);
  SELECT LAST_INSERT_ID() AS id_tarjeta;
END$$

DROP PROCEDURE IF EXISTS sp_eliminar_tarjeta$$
CREATE PROCEDURE sp_eliminar_tarjeta(IN p_id_tarjeta INT)
SQL SECURITY DEFINER
BEGIN
  DELETE FROM tarjeta WHERE id_tarjeta = p_id_tarjeta;
  IF ROW_COUNT() = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La tarjeta no existe';
  END IF;
END$$


-- Procedimientos del administrador: atajos que devuelven el id creado

DROP PROCEDURE IF EXISTS sp_programar_partido$$
CREATE PROCEDURE sp_programar_partido(
  IN p_id_torneo INT, IN p_numero_fecha INT, IN p_local INT, IN p_visitante INT,
  IN p_dia DATE, IN p_id_turno INT, IN p_cancha VARCHAR(50), IN p_id_complejo INT)
SQL SECURITY DEFINER
BEGIN
  INSERT INTO partido (id_torneo, numero_fecha, id_equipo_local, id_equipo_visitante,
                       dia, id_turno, nombre_cancha, id_complejo, estado)
  VALUES (p_id_torneo, p_numero_fecha, p_local, p_visitante,
          p_dia, p_id_turno, p_cancha, p_id_complejo, 'programado');
  SELECT LAST_INSERT_ID() AS id_partido;
END$$

DROP PROCEDURE IF EXISTS sp_sancion_disciplinaria$$
CREATE PROCEDURE sp_sancion_disciplinaria(
  IN p_ci VARCHAR(8), IN p_id_torneo INT, IN p_fecha_inicio INT, IN p_cantidad INT)
SQL SECURITY DEFINER
BEGIN
  INSERT INTO sancion_jugador (ci_jugador, id_torneo, motivo, numero_fecha_inicio, cantidad_fechas)
  VALUES (p_ci, p_id_torneo, 'disciplinaria', p_fecha_inicio, p_cantidad);
  SELECT LAST_INSERT_ID() AS id_sancion;
END$$

DROP PROCEDURE IF EXISTS sp_cambiar_estado_torneo$$
CREATE PROCEDURE sp_cambiar_estado_torneo(IN p_id_torneo INT, IN p_estado VARCHAR(20))
SQL SECURITY DEFINER
BEGIN
  UPDATE torneo SET estado = p_estado WHERE id_torneo = p_id_torneo;
END$$

DELIMITER ;
