<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
		version="1.0">

  <xsl:output method="text"/>



  <xsl:template name="device-name">
    <xsl:value-of select="/plist/dict/key[text()='Device Name'][1]/following-sibling::string[1]/text()"/>
  </xsl:template>



  <xsl:template match="/">
    <xsl:call-template name="device-name"/>
  </xsl:template>



</xsl:stylesheet>
