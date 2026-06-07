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
 * Servlet de Consulta de Saldos Filtrada.
 * Permite filtrar las cuentas del usuario por tipo (AHORROS/CORRIENTE).
 */
@WebServlet("/consulta/saldos-filtrado")
public class ConsultaSaldoFiltradoServlet extends HttpServlet {

    @EJB
    private CuentaServiceLocal cuentaService;

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res)
            throws ServletException, IOException {

        Usuario usuario = (Usuario) req.getSession().getAttribute("usuario");
        
        // Obtener el parámetro de filtro
        String tipoCuenta = req.getParameter("tipo");
        
        List<Cuenta> cuentas;
        
        // Si hay filtro, aplicarlo; si no, mostrar todas
        if (tipoCuenta != null && !tipoCuenta.isEmpty() && !tipoCuenta.equals("TODAS")) {
            cuentas = cuentaService.obtenerCuentasUsuarioPorTipo(usuario.getId(), tipoCuenta);
        } else {
            cuentas = cuentaService.obtenerCuentasUsuario(usuario.getId());
        }
        
        req.setAttribute("cuentas", cuentas);
        req.setAttribute("tipoFiltro", tipoCuenta != null ? tipoCuenta : "TODAS");
        req.getRequestDispatcher("/WEB-INF/views/consulta-saldo-filtrado.jsp").forward(req, res);
    }
}

// Made with Bob
