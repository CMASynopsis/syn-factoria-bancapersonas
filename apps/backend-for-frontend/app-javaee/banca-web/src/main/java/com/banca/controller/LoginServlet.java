package com.banca.controller;

import com.banca.model.Usuario;
import com.banca.service.AuthServiceLocal;

import javax.ejb.EJB;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;
import java.io.IOException;

@WebServlet("/login")
public class LoginServlet extends HttpServlet {

    @EJB
    private AuthServiceLocal authService;

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res)
            throws ServletException, IOException {
        HttpSession session = req.getSession(false);
        if (session != null && session.getAttribute("usuario") != null) {
            res.sendRedirect(req.getContextPath() + "/home");
            return;
        }
        req.getRequestDispatcher("/WEB-INF/views/login.jsp").forward(req, res);
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse res)
            throws ServletException, IOException {
        String username = req.getParameter("username");
        String password = req.getParameter("password");

        AuthServiceLocal.LoginResult result = authService.login(username, password);

        if (result.isExitoso()) {
            HttpSession session = req.getSession(true);
            session.setAttribute("usuario", result.getUsuario());
            session.setMaxInactiveInterval(30 * 60);
            res.sendRedirect(req.getContextPath() + "/home");
        } else {
            req.setAttribute("errorMsg", result.getMensaje());
            req.setAttribute("usernameInput", username);
            req.getRequestDispatcher("/WEB-INF/views/login.jsp").forward(req, res);
        }
    }
}
