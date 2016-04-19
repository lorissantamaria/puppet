######################################################################
#
# Clase de puppet que permite a clientes Debian, ubuntu y redhat
# conectarse a un directorio ldap con seguridad kerberos
#
# Esta clase configura tambien un cache de nombres y un cache de credenciales
# para permitir la autenticacion de los usuarios cuando no esta disponible
# el servidor de directorio
#
# Reorganizado el 22/03/2013 por s.o. y version
#
# Original 02/09/2008 por Loris Santamaria <loris@lgs.com.ve>
#
######################################################################

#Definiciones comunes a las demas clases
class directorio (
	$realm = "REINO.COM",
	$domain = "dominiodns.com",
	$trustedrealm = "AD.REINO.COM",
	$trusteddomain = "ad.dominiodns.com",
	$k5loginusers = "admin@REINO.COM",
	$k5desausers = "desa@REINO.COM",
	$k5soporteusers = "soporte@REINO.COM",
	$suffix = "dc=example,dc=com",
	$ldapservers = "miservidorldap.dominiodns.com",
	$is_ipa_server = "no"
		) {

	require yum

        package {
            "ipa-client":
                ensure => present;
            "openldap-clients":
                ensure => present;
            "krb5-workstation":
                ensure => present;
	    "cyrus-sasl-gssapi":
                ensure => present;
            "sssd":
                ensure => present;
#            "sssd-dbus":
#                ensure => $lsbmajdistrelease ? {
#                        "5"     => absent,
#                        default => present,
#                };
            "sudo":
                ensure => present;
        }
        file { 
	    "/etc/nss_ldap.conf":
		content => template('directorio/nss_ldap.conf.erb');
	    "/etc/ldap.conf":
		ensure  => "/etc/nss_ldap.conf",
		require => File["/etc/nss_ldap.conf"];
	    "/etc/openldap/ldap.conf":
		content => template('directorio/ldap.conf.erb'),
		require => Package["openldap-clients"];
	    "/etc/krb5.conf":
		content => template('directorio/krb5.conf.erb'),
		require => Package["krb5-workstation"];
 	    "/etc/sssd/sssd.conf":
		content => template('directorio/sssd.conf.erb'),
		owner   => "root",
		group   => "root",
		mode    => "0600",
		require => Package["sssd"];
#		require => [ Package["sssd"], Package["sssd-dbus"] ];
	    "/etc/nsswitch.conf":
		content => template('directorio/nsswitch.conf.erb'),
		require => Package["ipa-client"];
	    "/root/.k5login":
		mode    => "0600",
		seltype => "krb5_home_t",
		seluser => "unconfined_u",
		require => K5login["/root/.k5login"];
	    "/home/desa/.k5login":
		mode    => "0600",
		owner   => "desa",
		group   => "desa",
		seltype => "krb5_home_t",
		seluser => "unconfined_u",
		require => K5login["/home/desa/.k5login"];
	    "/home/soporte/.k5login":
		mode    => "0600",
		owner	=> "soporte",
		group	=> "soporte",
		seltype => "krb5_home_t",
		seluser => "unconfined_u",
		require => K5login["/home/soporte/.k5login"];
	}
	k5login {
	    "/root/.k5login":
		mode       => "600",
		principals => [ $k5loginusers ];
	    "/home/desa/.k5login":
		mode       => "600",
		principals => [ $k5desausers ];
	    "/home/soporte/.k5login":
		mode       => "600",
		principals => [ $k5soporteusers ];
	}
	service { "sssd":
		enable    => true,
		ensure    => running,
		require   => File["/etc/sssd/sssd.conf"],
		subscribe => File["/etc/sssd/sssd.conf"];
	}
}
