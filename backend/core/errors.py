def is_network_error(e):
    # check if offline.
    err_str = str(e).lower()
    network_keywords = [
        "connection", "connerror", "timeout", "timed out", "gaierror", 
        "name resolution", "temporary failure", "network is unreachable", 
        "host is unreachable", "max retries exceeded", "socket", 
        "dns", "unreachable", "handshake failed", "sslerror", "getaddrinfo"
    ]
    if any(k in err_str for k in network_keywords):
        return True
    
    # check exception class names
    cls_name = e.__class__.__name__.lower()
    if any(k in cls_name for k in ["connection", "timeout", "gaierror", "urlerror", "maxretry", "sslerror"]):
        return True
    
    return False
