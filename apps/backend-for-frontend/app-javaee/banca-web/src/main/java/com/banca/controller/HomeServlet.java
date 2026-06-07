package com.banca.controller;

import com.banca.dao.TransferenciaDAO;
import com.banca.model.Usuario;
import com.banca.service.CuentaServiceLocal;

import javax.annotation.Resource;
import javax.ejb.EJB;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;
import javax.sql.DataSource;
import java.io.IOException;
import java.sql.Connection;
import java.sql.SQLException;
import java.util.ArrayList;

@WebServlet("/home")
public class HomeServlet extends HttpServlet {

    @EJB
    private CuentaServiceLocal cuentaService;

    @Resource(lookup = "java:jboss/datasources/BancaDS")
    private DataSource dataSource;

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res)
            throws ServletException, IOException {
        Usuario usuario = (Usuario) req.getSession().getAttribute("usuario");

        req.setAttribute("cuentas", cuentaService.obtenerCuentasUsuario(usuario.getId()));

        // Historial de transferencias
        try (Connection conn = dataSource.getConnection()) {
            req.setAttribute("transferencias",
                new TransferenciaDAO().findByUsuario(conn, usuario.getId()));
        } catch (SQLException e) {
            req.setAttribute("transferencias", new ArrayList<>());
        }

        req.getRequestDispatcher("/WEB-INF/views/home.jsp").forward(req, res);
    }
}
