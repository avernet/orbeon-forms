<!--
    Copyright (C) 2004 Orbeon, Inc.

    This program is free software; you can redistribute it and/or modify it under the terms of the
    GNU Lesser General Public License as published by the Free Software Foundation; either version
    2.1 of the License, or (at your option) any later version.

    This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
    without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
    See the GNU Lesser General Public License for more details.

    The full text of the license is available at http://www.gnu.org/copyleft/lesser.html
-->
<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xforms="http://www.w3.org/2002/xforms"
    xmlns:xxforms="http://orbeon.org/oxf/xml/xforms"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:saxon="http://saxon.sf.net/"
    xmlns:f="http://orbeon.org/oxf/xml/formatting"
    xmlns:xhtml="http://www.w3.org/1999/xhtml"
    exclude-result-prefixes="xforms xxforms xs saxon xhtml f">

    <xsl:import href="oxf:/oxf/xslt/utils/copy.xsl"/>
    <xsl:output name="xml" method="xml"/>

    <xsl:variable name="request" as="element()" 
        select="doc('input:request')/xxforms:event-request"/>
    <xsl:variable name="response" as="element()" 
        select="doc('input:response')/xxforms:event-response"/>
    
    <!-- - - - - - - Form with hidden divs - - - - - - -->
    
    <xsl:template match="xhtml:body">
        <xsl:copy>
            <xsl:apply-templates select="@*"/>
            <xhtml:form class="xforms-form">
                <!-- Store private information used by the client-side JavaScript -->
                <xhtml:input type="hidden" name="$models" value="{$request/xxforms:models}"/>
                <xhtml:input type="hidden" name="$controls" value="{$request/xxforms:controls}"/>
                <xhtml:input type="hidden" name="$instances" value="{$response/xxforms:instances}"/>
                <xhtml:span class="xforms-loading-indicator"/>
                <xhtml:span class="xforms-loading-error"/>
                <xsl:apply-templates/>
            </xhtml:form>
        </xsl:copy>
    </xsl:template>
    
    <!-- - - - - - - XForms controls - - - - - - -->
    
    <xsl:template match="xforms:output | xforms:trigger | xforms:input 
            | xforms:secret | xforms:textarea" priority="2">
        <xsl:if test="local-name() != 'trigger'">
            <xsl:apply-templates select="xforms:label"/>
        </xsl:if>
        <xsl:next-match/>
        <xsl:apply-templates select="xforms:help"/>
        <xhtml:label for="{@id}">
            <xsl:copy-of select="xxforms:copy-attributes(xforms:alert, concat('xforms-alert-', 
                if (xxforms:control(@id)/@valid = 'false') then 'active' else 'inactive'))"/>
            <xsl:value-of select="xxforms:control(@id)/@alert"/>
        </xhtml:label>
        <xsl:apply-templates select="xforms:hint"/>
    </xsl:template>
    
    <xsl:template match="xforms:output">
        <xhtml:span>
            <xsl:copy-of select="xxforms:copy-attributes(., 'xforms-control')"/>
            <xsl:value-of select="xxforms:control(@id)"/>
        </xhtml:span>
    </xsl:template>
    
    <xsl:template match="xforms:trigger">
        <xhtml:button type="button" class="trigger">
            <xsl:copy-of select="xxforms:copy-attributes(., 'xforms-control')"/>
            <xsl:value-of select="xforms:label"/>
        </xhtml:button>
    </xsl:template>
    
    <xsl:template match="xforms:input">
        <xhtml:input type="text" name="{@id}" value="{xxforms:control(@id)}">
            <xsl:copy-of select="xxforms:copy-attributes(., 'xforms-control')"/>
        </xhtml:input>
    </xsl:template>

    <xsl:template match="xforms:secret">
        <xhtml:input type="password" name="{@id}" value="{xxforms:control(@id)}">
            <xsl:copy-of select="xxforms:copy-attributes(., 'xforms-control')"/>
        </xhtml:input>
    </xsl:template>

    <xsl:template match="xforms:textarea">
        <xhtml:textarea name="{@id}">
            <xsl:copy-of select="xxforms:copy-attributes(., 'xforms-control')"/>
            <xsl:value-of select="xxforms:control(@id)"/>
        </xhtml:textarea>
    </xsl:template>
    
    <xsl:template match="xforms:label | xforms:hint | xforms:help">
        <xhtml:label for="{../@id}">
            <xsl:copy-of select="xxforms:copy-attributes(., concat('xforms-', local-name()))"/>
            <xsl:variable name="value-element" as="element()" select="xxforms:control(../@id)"/>
            <xsl:value-of select="if (local-name() = 'label') then $value-element/@label
                else if (local-name() = 'hint') then $value-element/@hint
                else $value-element/@help"/>
        </xhtml:label>
    </xsl:template>

    <!-- - - - - - - XForms containers - - - - - - -->

    <xsl:template match="xforms:group|xforms:switch">
        <xhtml:span>
            <xsl:copy-of select="xxforms:copy-attributes(., concat('xforms-', local-name()))"/>
            <xsl:apply-templates/>
        </xhtml:span>
    </xsl:template>
    
    <xsl:template match="xforms:case">
        <!-- FIXME: use reponse to figure out what case are displayed -->
        <xhtml:span>
            <xsl:copy-of select="xxforms:copy-attributes(., 'xforms-case')"/>
            <xsl:attribute name="style" select="concat('display: ', 
                if (true()) then 'block' else 'none')"/>
            <xsl:apply-templates/>
        </xhtml:span>
    </xsl:template>
    
    <!-- - - - - - - Utility templates and functions - - - - - - -->

    <xsl:template match="xforms:*"/>
    
    <xsl:function name="xxforms:copy-attributes">
        <xsl:param name="element" as="element()?"/>
        <xsl:param name="classes" as="xs:string*"/>
        <!-- Copy attributes with no namespaces -->
        <xsl:copy-of select="$element/@id | $element/@accesskey | $element/@tabindex | $element/@style"/>
        <!-- Convert navindex to tabindex -->
        <xsl:if test="$element/@navindex">
            <xsl:attribute name="tabindex" select="$element/@navindex"/>
        </xsl:if>
        <!-- Copy class attribute, both in xhtml namespace and no namespace -->
        <xsl:variable name="class" as="xs:string" select="string-join
            (($element/@xhtml:class, $element/@class, $classes, 
            if ($element/@incremental = 'true') then 'xforms-incremental' else ()), ' ')"/>
        <xsl:attribute name="class" select="$class"/>
        <!-- Copy attributes in the xhtml namespace to no namespace -->
        <xsl:for-each select="$element/@xhtml:* except $element/@xhtml:class">
            <xsl:attribute name="{local-name()}" select="."/>
        </xsl:for-each>
    </xsl:function>
    
    <xsl:function name="xxforms:control" as="element()">
        <xsl:param name="id" as="xs:string"/>
        <xsl:sequence select="$response/xxforms:control-values/xxforms:control[@id = $id]"/>
    </xsl:function>
    
</xsl:stylesheet>
