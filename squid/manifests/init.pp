class squid (
	$libdir            = "lib64",
	$negotiate_helper  = "negotiate_kerberos_auth",
	$basic_auth_helper = "basic_pam_auth",
	$group_helper      = "ext_ldap_group_acl",
    $ipa_server        = "my.ipa.server.com",
	$ldap_search_base  = "dc=midominio,dc=com",
	$ldap_query        = "(&(cn=%g)(memberuid=%u))",
	$ldap_uri          = "ldap://miservidor.com:389/",
	$puertos           = [ "8080", "8081" ],
	$puertos_ssl       = [ "8080", "8081" ],
	$networkinvitados  = undef,
	$pag_permitidas    = [ ".mipagina1.com", ".mipagina2.com" ],
	$pag_bloqueadas    = [ ".bloqueada1.com", ".bloqueada2.com" ],
	$ip_libres         = [ "192.168.3.4", "192.168.4.5" ],
	$ip_reguladas	   = [ "192.168.5.4", "192.168.5.6" ],
	$snmpcommunity     = "public",
	$snmpserver        = "mi.servidor.snmp",
	$cache_peers       = undef,
	$default_domain    = "midominio.com",
	$mgr_email	   = "soporte@midominio.com"
	) {

	require snmp
	require directorio

        package {
            "squid":
                ensure => present;
        }
	exec {
	    "squid-getkeytab":
		command => "ipa-getkeytab -k /etc/squid/squid.keytab -p HTTP/$fqdn -s $ipa_server",
		path    => "/bin:/sbin:/usr/bin:/usr/sbin",
		creates => "/etc/squid/squid.keytab";
	}
        file {
	    "/etc/squid/squid.keytab":
		ensure  => present,
                owner   => "root",
                group   => "squid",
                mode    => "640",
		require => Exec["squid-getkeytab"];
	    "/etc/sysconfig/squid":
                source  => "puppet:///modules/squid/squid.sysconfig",
		require => File["/etc/squid/squid.keytab"];
            "/etc/squid/squid.conf":
		content => template('squid/squid.conf.erb'),
                owner   => "root",
                group   => "squid",
                mode    => "640",
		require =>  [ 
			File["/etc/sysconfig/squid"],
			File["/etc/squid/ip_libres"],
			File["/etc/squid/ip_reguladas"],
			File["/etc/squid/pag_permitidas"],
			File["/etc/squid/pag_bloqueadas"]
			     ];
	    "/etc/squid/ip_libres":
		content => template('squid/ip_libres.erb'),
                owner   => "root",
                group   => "squid",
                mode    => "644";
	    "/etc/squid/ip_reguladas":
		content => template('squid/ip_reguladas.erb'),
                owner   => "root",
                group   => "squid",
                mode    => "644";
	    "/etc/squid/pag_permitidas":
		content => template('squid/pag_permitidas.erb'),
                owner   => "root",
                group   => "squid",
                mode    => "644";
	    "/etc/squid/pag_bloqueadas":
		content => template('squid/pag_bloqueadas.erb'),
                owner   => "root",
                group   => "squid",
                mode    => "644";
            "/etc/snmp/snmpd.local.conf-squid":
		name    => "/etc/snmp/snmpd.local.conf",
                source  => "puppet:///modules/squid/snmpd.local.conf",
                require => File["/etc/snmp/snmpd.conf"];
            "/etc/pam.d/squid":
                source  => "puppet:///modules/squid/squid.pam";
        }
        service {
            "squid":
                ensure    => running,
                enable    => true,
		restart   => "/sbin/service squid reload",
                require   => Package["squid"],
                subscribe => [ 
			File["/etc/squid/squid.conf"],
			File["/etc/squid/ip_libres"],
			File["/etc/squid/ip_reguladas"],
			File["/etc/squid/pag_permitidas"],
			File["/etc/squid/pag_bloqueadas"]
			     ];
        }
} 
class squid::wpad (
	$zonas = { 
		zona1 => { 
			"subred" => "192.168.0.0",
			"proxy"  => "miproxy.midominio.com:8080"
		},
		zona2 => { 
			"subred" => "192.168.1.0",
			"proxy"  => "miproxy2.midominio.com:8080"
		}
	}
		) {

	require apache

        file {
            "/var/www/html/proxy.pac":
		content => template('squid/proxy.pac.erb'),
		ensure  => "present";
            "/var/www/html/wpad.dat":
		require => File["/var/www/html/proxy.pac"],
		ensure  => "/var/www/html/proxy.pac";
            "/etc/httpd/conf.d/wpad.conf":
                source  => "puppet:///modules/squid/wpad.conf",
		ensure  => "present";
	}
}

class squid::guard {
	package {
	    "ufdbGuard":
		ensure => present;
	}
	file {
	  "/usr/local/bin/execuserlist.sh":
		content => template('squid/execuserlist.sh.erb')
		mode    => "755";
	  "/usr/local/bin/actualizaufdb.sh":
		source  => "puppet:///modules/squid/actualizaufdb.sh",
		mode    => "755";
	  "/etc/ufdbguard/ufdbGuard.conf":
		source  => "puppet:///modules/squid/ufdbGuard.conf",
		owner   => "ufdb",
		group   => "ufdb",
		mode    => "644",
		require => [ Package["ufdbGuard"], File["/usr/local/bin/execuserlist.sh"] ];
	  "/var/ufdbguard/bigblacklist.tar.gz":
		source  => "puppet:///modules/squid/bigblacklist.tar.gz",
		require => Package["ufdbGuard"];
	}
	exec {
	    "actualizadb":
                command => "/usr/local/bin/actualizaufdb.sh",
                path    => "/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin",
		onlyif  => "test /var/ufdbguard/bigblacklist.tar.gz -nt /var/ufdbguard/blacklists/adult/domains.ufdb",
                require => [ Package["ufdbGuard"], File["/var/ufdbguard/bigblacklist.tar.gz"], File["/usr/local/bin/actualizaufdb.sh"] ];
        } 
	service {
	    "ufdb":
		ensure    => running,
                enable    => true,
                require   => [ File["/etc/ufdbguard/ufdbGuard.conf"], Exec["actualizadb"] ],
		subscribe => File["/etc/ufdbguard/ufdbGuard.conf"];
	}
}
