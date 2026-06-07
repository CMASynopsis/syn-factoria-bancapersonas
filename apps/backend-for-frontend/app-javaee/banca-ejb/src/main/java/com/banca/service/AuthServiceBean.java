package com.banca.service;

import com.banca.dao.UsuarioDAO;
import com.banca.model.Usuario;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.mindrot.jbcrypt.BCrypt;

import javax.annotation.Resource;
import javax.ejb.Stateless;
import javax.ejb.TransactionAttribute;
import javax.ejb.TransactionAttributeType;
import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.SQLException;

/**
 * EJB Stateless de autenticación.
 *
 * DataSource: java:jboss/datasources/BancaDS
 * Configurado en WildFly 10.1 standalone.xml apuntando a MySQL 5.7
 */
@Stateless
@TransactionAttribute(TransactionAttributeType.REQUIRED)
public class AuthServiceBean implements AuthServiceLocal {

    private static final Logger logger = LogManager.getLogger(AuthServiceBean.class);

    @Resource(lookup = "java:jboss/datasources/BancaDS")
    private DataSource dataSource;

    @Override
    public LoginResult login(String username, String password) {

        if (username == null || username.trim().isEmpty())
            return new LoginResult(false, "El usuario es requerido.", null);
        if (password == null || password.trim().isEmpty())
            return new LoginResult(false, "La contraseña es requerida.", null);

        try (Connection conn = dataSource.getConnection()) {
            UsuarioDAO dao = new UsuarioDAO();
            Usuario usuario = dao.findByUsername(conn, username.trim());

            if (usuario == null) {
                logger.warn("Login fallido - usuario no existe: {}", username);
                return new LoginResult(false, "Usuario o contraseña incorrectos.", null);
            }

            // Verificar hash BCrypt
            if (!BCrypt.checkpw(password, usuario.getPassword())) {
                dao.incrementarIntentosFallidos(conn, username.trim());
                logger.warn("Login fallido - contraseña incorrecta: {}", username);
                return new LoginResult(false, "Usuario o contraseña incorrectos.", null);
            }

            dao.resetearIntentosFallidos(conn, username.trim());
            dao.updateUltimoAcceso(conn, usuario.getId());
            logger.info("Login exitoso: {}", username);
            return new LoginResult(true, "Bienvenido.", usuario);

        } catch (SQLException e) {
            logger.error("Error BD en login usuario: {}", username, e);
            return new LoginResult(false, "Error interno. Intente nuevamente.", null);
        }
    }
}
