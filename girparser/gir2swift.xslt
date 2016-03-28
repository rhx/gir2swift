<?xml version="1.0" encoding="UTF-8"?>
<xsl:transform version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xpath-default-namespace="http://www.gtk.org/introspection/core/1.0" xmlns:c="http://www.gtk.org/introspection/c/1.0">
<xsl:output method="text" encoding="UTF-8"/>
<xsl:template name ="struct">
	<xsl:param name ="type"/>
	<xsl:param name ="content"/>
	<xsl:param name ="ctype"/>
public struct <xsl:value-of select="$type"/> {
    public let <xsl:value-of select="$content"/>: <xsl:value-of select="$ctype"/>
}
</xsl:template>
<xsl:template match="/">//
// This file was automatically created by gir2swift.xlst
// DO NOT MODIFY MANUALLY
//
<xsl:apply-templates />
</xsl:template>
<xsl:template match="record">
	<xsl:call-template name ="struct">
        <xsl:with-param name ="type" select ="@name"></xsl:with-param>
        <xsl:with-param name ="content">content</xsl:with-param>
        <xsl:with-param name ="ctype" select ="@c:type"></xsl:with-param>
    </xsl:call-template>
</xsl:template>
<!--
<xsl:for-each select="//function">
func <xsl:value-of select="@name"/>(
<xsl:for-each select="parameters"><xsl:value-of select="@name"/> </xsl:for-each>
) -> <xsl:value-of select="."/>
</xsl:for-each>
-->

</xsl:transform>
