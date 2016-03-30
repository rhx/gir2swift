<?xml version="1.0" encoding="UTF-8"?>
<xsl:transform version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xpath-default-namespace="http://www.gtk.org/introspection/core/1.0" xmlns:c="http://www.gtk.org/introspection/c/1.0" xmlns:glib="http://www.gtk.org/introspection/glib/1.0">
<xsl:output method="text" encoding="UTF-8"/>
<xsl:variable name="ptrcontent">ptr</xsl:variable>
<xsl:variable name="content">content</xsl:variable>

<!-- translate method parameters to Swift -->
<xsl:template name="methodparams">
	<xsl:param name ="params"/>
	<xsl:param name ="type"/>
	<xsl:param name ="cname"/>
	<xsl:variable name="i" select="0" />
    <xsl:for-each select="$params">
		<xsl:variable name="i" select="1+$i" />
		<xsl:variable name="tname" select="type/@name" />
		<xsl:variable name="name" select="@name" />
		<xsl:variable name="lname" select="lower-case($name)" />
<xsl:if test="not(position()=1)">, _ </xsl:if><xsl:value-of select="$lname"/>: <xsl:value-of select="$tname"/>
    </xsl:for-each>
</xsl:template>

<xsl:template name="paramvals">
	<xsl:param name ="params"/>
	<xsl:param name ="type"/>
	<xsl:param name ="cname"/>
	<xsl:variable name="i" select="0" />
    <xsl:for-each select="$params">
		<xsl:variable name="i" select="1+$i" />
		<xsl:variable name="tname" select="type/@name" />
		<xsl:variable name="name" select="@name" />
		<xsl:variable name="lname" select="lower-case($name)" />, <xsl:value-of select="$lname"/>
    </xsl:for-each>
</xsl:template>

<!-- Method wrapper -->
<xsl:template name="method">
	<xsl:param name ="name"/>
	<xsl:param name ="params"/>
	<xsl:param name ="type"/>
	<xsl:param name ="cname"/>
    public func <xsl:value-of select="$name"/>(<xsl:call-template name ="methodparams">
	    <xsl:with-param name ="params" select="$params" />
	    <xsl:with-param name ="type" select="$type" />
	    <xsl:with-param name ="cname" select="$cname" />
	    </xsl:call-template>) -> <xsl:value-of select="$type" /> {
        return <xsl:value-of select="$cname"/>(<xsl:value-of select="$ptrcontent"/><xsl:call-template name ="paramvals">
	    <xsl:with-param name ="params" select="$params" />
	    <xsl:with-param name ="type" select="$type" />
	    <xsl:with-param name ="cname" select="$cname" />
	    </xsl:call-template>)
    }
</xsl:template>

<!-- Base protocol for all records -->
<xsl:template name ="protocol">
	<xsl:param name ="ns"/>
	<xsl:param name ="type"/>
	<xsl:param name ="ctype"/>
	<xsl:param name ="gettype"/>
public protocol <xsl:value-of select="$ns"/><xsl:value-of select="$type"/>Type {
    var <xsl:value-of select="$ptrcontent"/>: UnsafeMutablePointer&lt;<xsl:value-of select="$ctype"/>&gt; { get }
}
</xsl:template>

<!-- Protocol extension with all methods -->
<xsl:template name ="protocolext">
	<xsl:param name ="ns"/>
	<xsl:param name ="type"/>
	<xsl:param name ="ctype"/>
public extension <xsl:value-of select="$ns"/><xsl:value-of select="$type"/>Type {
    <xsl:for-each select="function">
		<xsl:variable name="qinstance" select="parameters/instance-parameter/type/@name" />
		<xsl:variable name="qarraytype" select="parameters/parameter[1]/array/@name" />
		<xsl:variable name="instance" select="replace($qinstance, '^[^.]*\.', '')" />
		<xsl:variable name="arraytype" select="replace($qarraytype, '^[^.]*\.', '')" />
		<xsl:variable name="allparameters" select="parameters/parameter" />
		<xsl:if test="($instance=$type) or ($arraytype=$type)">
			<xsl:variable name="name" select="@name" />
			<xsl:variable name ="parameters" select="if ($instance=$type) then ($allparameters) else (subsequence($allparameters,2))" />
			<xsl:variable name="qrv" select="return-value/type/@name" />
			<xsl:variable name="qarv" select="return-value/array/type/@name" />
			<xsl:variable name="irv" select="replace($qrv, '^[^.]*\.', '')" />
			<xsl:variable name="arv" select="replace($qarv, '^[^.]*\.', '')" />
			<xsl:variable name="rv" select="if ($irv='') then (if (($arv=$type) or ($arv='')) then ('Void') else ($arv)) else ($irv)" />
			<xsl:call-template name ="method">
     		   <xsl:with-param name ="name" select="$name" />
     		   <xsl:with-param name ="params" select="$parameters" />
	 		   <xsl:with-param name ="type" select="$rv" />
	 		   <xsl:with-param name ="cname" select="@c:identifier" />
    		</xsl:call-template>
		</xsl:if>
    </xsl:for-each>
}
</xsl:template>

<!-- Basic implemetation via struct -->
<xsl:template name ="struct">
	<xsl:param name ="ns"/>
	<xsl:param name ="type"/>
	<xsl:param name ="ctype"/>
public struct <xsl:value-of select="$ns"/><xsl:value-of select="$type"/>: <xsl:value-of select="$ns"/><xsl:value-of select="$type"/>Type {
    public var <xsl:value-of select="$ptrcontent"/>: UnsafeMutablePointer&lt;<xsl:value-of select="$ctype"/>&gt;
}
</xsl:template>

<!-- Memory-managed implementation via class -->
<xsl:template name ="class">
	<xsl:param name ="ns"/>
	<xsl:param name ="type"/>
	<xsl:param name ="ctype"/>
public class <xsl:value-of select="$ns"/><xsl:value-of select="$type"/>: <xsl:value-of select="$ns"/><xsl:value-of select="$type"/>Type {
    public let <xsl:value-of select="$content"/>: <xsl:value-of select="$ns"/><xsl:value-of select="$type"/>
    public var <xsl:value-of select="$ptrcontent"/>: UnsafeMutablePointer&lt;<xsl:value-of select="$ctype"/>&gt; {
        return <xsl:value-of select="$content"/>.<xsl:value-of select="$ptrcontent"/>
    }

	public init(_ c: <xsl:value-of select="$ns"/><xsl:value-of select="$type"/>) {
		<xsl:value-of select="$content"/> = c
	}

	public init(_ <xsl:value-of select="$ptrcontent"/>: UnsafeMutablePointer&lt;<xsl:value-of select="$ctype"/>&gt;) {
		self.init(<xsl:value-of select="$ns"/><xsl:value-of select="$type"/>(<xsl:value-of select="$ptrcontent"/>: <xsl:value-of select="$ptrcontent"/>))
	}

	public convenience init&lt;T&gt;(<xsl:value-of select="$ptrcontent"/>: UnsafeMutablePointer&lt;T&gt;) {
		self.init(<xsl:value-of select="$ns"/><xsl:value-of select="$type"/>(UnsafeMutablePointer&lt;<xsl:value-of select="$ctype"/>&gt;(<xsl:value-of select="$ptrcontent"/>)))
	}
}
</xsl:template>

<xsl:template match="/">//
// This file was automatically created by gir2swift.xlst
// DO NOT MODIFY MANUALLY
//
<xsl:variable name="namespace" select="namespace/@name" />
<xsl:apply-templates />
</xsl:template>
<xsl:template match="namespace">
<xsl:apply-templates />
</xsl:template>

<xsl:template match="alias">
<xsl:apply-templates />
typealias <xsl:value-of select="@name"/> = <xsl:value-of select="type/@name"/>
</xsl:template>

<xsl:template match="record">
	<xsl:call-template name ="protocol">
        <xsl:with-param name ="ns" select="ancestor::namespace/@name" />
        <xsl:with-param name ="type" select="@name" />
        <xsl:with-param name ="ctype" select="@c:type" />
    </xsl:call-template>
	<xsl:call-template name ="protocolext">
        <xsl:with-param name ="ns" select="ancestor::namespace/@name" />
        <xsl:with-param name ="type" select="@name" />
        <xsl:with-param name ="ctype" select="@c:type" />
    </xsl:call-template>
</xsl:template>

<xsl:template match="doc">
<xsl:variable name="newline-regex">\n</xsl:variable>
<xsl:variable name="newline-rep">
/// </xsl:variable>
<xsl:variable name="content" select="." />
/// <xsl:value-of select="replace($content, $newline-regex, $newline-rep)" />
</xsl:template>

</xsl:transform>
