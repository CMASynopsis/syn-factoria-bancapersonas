package com.banca.controller;

import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;
import java.io.IOException;

@WebServlet("/logout")
public class LogoutServlet extends HttpServlet {
    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res)
            throws ServletException, IOException {
        HttpSession s = req.getSession(false);
        if (s != null) s.invalidate();
        res.sendRedirect(req.getContextPath() + "/login");
    }
    @Override protected void doPost(HttpServletRequest req, HttpServletResponse res)
            throws ServletException, IOException { doGet(req, res); }
}
