package com.banca.service;

import com.banca.model.Usuario;

/**
 * Interfaz local del EJB de autenticación.
 * Inyectada en los Servlets del módulo WAR mediante @EJB.
 */
public interface AuthServiceLocal {

    class LoginResult {
        private final boolean exitoso;
        private final String mensaje;
        private final Usuario usuario;

        public LoginResult(boolean exitoso, String mensaje, Usuario usuario) {
            this.exitoso = exitoso;
            this.mensaje = mensaje;
            this.usuario = usuario;
        }
        public boolean isExitoso()    { return exitoso; }
        public String getMensaje()    { return mensaje; }
        public Usuario getUsuario()   { return usuario; }
    }

    LoginResult login(String username, String password);
}
