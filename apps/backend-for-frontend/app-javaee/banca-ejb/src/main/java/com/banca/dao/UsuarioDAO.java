package com.banca.dao;

import com.banca.model.Usuario;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import java.sql.*;
import java.util.Date;

/**
 * DAO de Usuario - compatible con MySQL 5.7
 * Recibe Connection desde el DataSource de WildFly (CMT).
 */
public class UsuarioDAO {

    private static final Logger logger = LogManager.getLogger(UsuarioDAO.class);

    public Usuario findByUsername(Connection conn, String username) throws SQLException {
        String sql = "SELECT id, username, password, nombres, apellidos, email, " +
                     "telefono, estado, rol, fecha_creacion, ultimo_acceso " +
                     "FROM usuario WHERE username = ? AND estado = 'ACTIVO'";
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, username);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) return map(rs);
            }
        }
        return null;
    }

    public void updateUltimoAcceso(Connection conn, Long id) throws SQLException {
        // MySQL 5.7: NOW() para timestamp actual
        String sql = "UPDATE usuario SET ultimo_acceso = NOW() WHERE id = ?";
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setLong(1, id);
            ps.executeUpdate();
        }
    }

    public void incrementarIntentosFallidos(Connection conn, String username) throws SQLException {
        String sql = "UPDATE usuario SET intentos_fallidos = intentos_fallidos + 1 WHERE username = ?";
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, username);
            ps.executeUpdate();
        }
    }

    public void resetearIntentosFallidos(Connection conn, String username) throws SQLException {
        String sql = "UPDATE usuario SET intentos_fallidos = 0 WHERE username = ?";
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, username);
            ps.executeUpdate();
        }
    }

    private Usuario map(ResultSet rs) throws SQLException {
        Usuario u = new Usuario();
        u.setId(rs.getLong("id"));
        u.setUsername(rs.getString("username"));
        u.setPassword(rs.getString("password"));
        u.setNombres(rs.getString("nombres"));
        u.setApellidos(rs.getString("apellidos"));
        u.setEmail(rs.getString("email"));
        u.setTelefono(rs.getString("telefono"));
        u.setEstado(rs.getString("estado"));
        u.setRol(rs.getString("rol"));
        Timestamp fc = rs.getTimestamp("fecha_creacion");
        if (fc != null) u.setFechaCreacion(new Date(fc.getTime()));
        Timestamp ua = rs.getTimestamp("ultimo_acceso");
        if (ua != null) u.setUltimoAcceso(new Date(ua.getTime()));
        return u;
    }
}
