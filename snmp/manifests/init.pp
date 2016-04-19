class snmp {
	package {
	  "net-snmp":
		ensure => present;
	}
	file {
	  "/etc/snmp/snmpd.conf":
	    owner   => root,
       	group   => root,
       	mode    => 640,
 	    source  => "puppet:///modules/snmp/snmpd.conf",
	    require => Package["net-snmp"];
      "/var/agentx":
	    ensure  => directory,
	    owner   => root,
       	group   => root,
       	mode    => 775,
	    require => Package["net-snmp"];
	}
	service {
	  "snmpd":
	    ensure    => running,
		enable    => true,
		require   => Package["net-snmp"],
		subscribe => File["/etc/snmp/snmpd.conf"];
	}
}
