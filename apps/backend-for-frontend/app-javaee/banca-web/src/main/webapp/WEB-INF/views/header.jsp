<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fn" uri="http://java.sun.com/jsp/jstl/functions" %>
<header class="navbar">
    <div class="navbar-brand">
        <svg viewBox="0 0 40 40" width="36" height="36" fill="none" xmlns="http://www.w3.org/2000/svg">
            <rect width="40" height="40" rx="8" fill="#1a3a6b"/>
            <path d="M6 28 L20 8 L34 28 Z" fill="#c8a84b" opacity="0.9"/>
            <rect x="9" y="28" width="22" height="3" rx="1" fill="#c8a84b"/>
            <rect x="15" y="20" width="3" height="8" fill="#1a3a6b"/>
            <rect x="22" y="20" width="3" height="8" fill="#1a3a6b"/>
        </svg>
        <span class="navbar-title">Banco Nacional</span>
    </div>

    <nav class="navbar-menu">

        <%-- Inicio --%>
        <a href="${pageContext.request.contextPath}/home"
           class="nav-link ${fn:contains(pageContext.request.servletPath, '/home') ? 'active' : ''}">
            🏠 Inicio
        </a>

        <%-- Consulta de Saldos --%>
        <div class="nav-dropdown">
            <button class="nav-link dropdown-toggle">💰 Consulta de Saldos ▾</button>
            <div class="dropdown-menu">
                <a href="${pageContext.request.contextPath}/consulta/saldos" class="dropdown-item">
                    📊 Ver todas las cuentas
                </a>
                <a href="${pageContext.request.contextPath}/consulta/saldos-filtrado" class="dropdown-item">
                    🔍 Consulta filtrada
                </a>
            </div>
        </div>

        <%-- Transferencias --%>
        <div class="nav-dropdown">
            <button class="nav-link dropdown-toggle">💸 Transferencias ▾</button>
            <div class="dropdown-menu">
                <a href="${pageContext.request.contextPath}/transferencia/propia" class="dropdown-item">
                    🔄 Entre mis cuentas
                </a>
                <a href="${pageContext.request.contextPath}/transferencia/mismo-banco" class="dropdown-item">
                    🏦 Mismo banco
                </a>
                <a href="${pageContext.request.contextPath}/transferencia/otro-banco" class="dropdown-item">
                    🌐 Otro banco (CCI)
                </a>
            </div>
        </div>

    </nav>

    <div class="navbar-user">
        <div class="user-info">
            <span class="user-avatar">
                ${fn:substring(usuario.nombres, 0, 1)}${fn:substring(usuario.apellidos, 0, 1)}
            </span>
            <span class="user-name">${usuario.nombres} ${usuario.apellidos}</span>
        </div>
        <a href="${pageContext.request.contextPath}/logout" class="btn btn-outline btn-sm">
            Salir
        </a>
    </div>
</header>

<script>
// Handle all dropdown toggles
document.querySelectorAll('.dropdown-toggle').forEach(function(toggle) {
    toggle.addEventListener('click', function() {
        this.closest('.nav-dropdown').classList.toggle('open');
    });
});

// Close dropdowns when clicking outside
document.addEventListener('click', function(e) {
    if (!e.target.closest('.nav-dropdown')) {
        document.querySelectorAll('.nav-dropdown').forEach(function(d){
            d.classList.remove('open');
        });
    }
});
</script>
