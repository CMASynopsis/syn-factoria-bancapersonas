<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Banco Nacional - Inicio</title>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/style.css">
</head>
<body>
<jsp:include page="header.jsp"/>

<main class="main-content">
    <div class="page-header">
        <h1>Bienvenido, <span class="highlight">${usuario.nombres}</span></h1>
        <p class="page-subtitle">Resumen de tus cuentas</p>
    </div>

    <%-- TARJETAS DE CUENTAS --%>
    <section class="section">
        <h2 class="section-title">Mis Cuentas</h2>
        <div class="accounts-grid">
            <c:choose>
                <c:when test="${empty cuentas}">
                    <div class="empty-state">
                        <p>No tienes cuentas activas registradas.</p>
                    </div>
                </c:when>
                <c:otherwise>
                    <c:forEach var="cuenta" items="${cuentas}">
                        <div class="account-card ${cuenta.tipoCuenta == 'AHORROS' ? 'card-savings' : 'card-current'}">
                            <div class="account-card-header">
                                <span class="account-type">${cuenta.tipoCuenta}</span>
                                <span class="account-currency">${cuenta.moneda}</span>
                            </div>
                            <div class="account-number">${cuenta.numeroCuentaFormateado()}</div>
                            <div class="account-balance-label">Saldo disponible</div>
                            <div class="account-balance">
                                <fmt:formatNumber value="${cuenta.saldoDisponible}" type="currency"
                                                  currencySymbol="${cuenta.moneda == 'PEN' ? 'S/' : '$'}"
                                                  minFractionDigits="2"/>
                            </div>
                            <div class="account-total">
                                Saldo total:
                                <fmt:formatNumber value="${cuenta.saldo}" type="currency"
                                                  currencySymbol="${cuenta.moneda == 'PEN' ? 'S/' : '$'}"
                                                  minFractionDigits="2"/>
                            </div>
                        </div>
                    </c:forEach>
                </c:otherwise>
            </c:choose>
        </div>
    </section>

    <%-- ACCESOS RÁPIDOS --%>
    <section class="section">
        <h2 class="section-title">Accesos Rápidos</h2>
        <div class="quick-actions">
            <a href="${pageContext.request.contextPath}/transferencia/propia" class="quick-action-btn">
                <span class="qa-icon">🔄</span>
                <span class="qa-label">Entre mis cuentas</span>
            </a>
            <a href="${pageContext.request.contextPath}/transferencia/mismo-banco" class="quick-action-btn">
                <span class="qa-icon">🏦</span>
                <span class="qa-label">Mismo banco</span>
            </a>
            <a href="${pageContext.request.contextPath}/transferencia/otro-banco" class="quick-action-btn">
                <span class="qa-icon">🌐</span>
                <span class="qa-label">Otro banco (CCI)</span>
            </a>
        </div>
    </section>

    <%-- ÚLTIMAS TRANSFERENCIAS --%>
    <section class="section">
        <h2 class="section-title">Últimas Operaciones</h2>
        <c:choose>
            <c:when test="${empty transferencias}">
                <div class="empty-state">
                    <p>No tienes operaciones recientes.</p>
                </div>
            </c:when>
            <c:otherwise>
                <div class="table-responsive">
                    <table class="data-table">
                        <thead>
                            <tr>
                                <th>Fecha</th>
                                <th>Tipo</th>
                                <th>Destino</th>
                                <th>Monto</th>
                                <th>Estado</th>
                            </tr>
                        </thead>
                        <tbody>
                            <c:forEach var="t" items="${transferencias}">
                                <tr>
                                    <td>
                                        <fmt:formatDate value="${t.fechaOperacion}" pattern="dd/MM/yyyy HH:mm"/>
                                    </td>
                                    <td>${t.tipoTransferenciaDescripcion()}</td>
                                    <td>
                                        <c:choose>
                                            <c:when test="${not empty t.titularDestino}">${t.titularDestino}</c:when>
                                            <c:otherwise>${t.cuentaDestinoNumero}</c:otherwise>
                                        </c:choose>
                                    </td>
                                    <td class="amount">
                                        <fmt:formatNumber value="${t.monto}" type="number" minFractionDigits="2"/>
                                        ${t.moneda}
                                    </td>
                                    <td>
                                        <span class="badge badge-${t.estado == 'PROCESADA' ? 'success' : t.estado == 'PENDIENTE' ? 'warning' : 'danger'}">
                                            ${t.estado}
                                        </span>
                                    </td>
                                </tr>
                            </c:forEach>
                        </tbody>
                    </table>
                </div>
            </c:otherwise>
        </c:choose>
    </section>
</main>

<footer class="app-footer">
    <p>&copy; 2024 Banco Nacional. Todos los derechos reservados.</p>
</footer>
</body>
</html>
