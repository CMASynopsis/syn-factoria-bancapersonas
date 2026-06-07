package com.banca.controller;

import com.banca.model.Cuenta;
import com.banca.model.Usuario;
import com.banca.service.CuentaServiceLocal;

import javax.ejb.EJB;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;
import java.io.IOException;
import java.util.List;

/**
 * Servlet de Consulta de Saldos.
 * Muestra todas las cuentas del usuario con sus saldos actuales.
 */
@WebServlet("/consulta/saldos")
public class ConsultaSaldoServlet extends HttpServlet {

    @EJB
    private CuentaServiceLocal cuentaService;

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res)
            throws ServletException, IOException {

        Usuario usuario = (Usuario) req.getSession().getAttribute("usuario");
        List<Cuenta> cuentas = cuentaService.obtenerCuentasUsuario(usuario.getId());
        req.setAttribute("cuentas", cuentas);
        req.getRequestDispatcher("/WEB-INF/views/consulta-saldo.jsp").forward(req, res);
    }
}
