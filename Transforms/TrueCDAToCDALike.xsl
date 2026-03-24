<!--
	CDA validation converter takes true CDA and
	expands to CFH CDA-like format by using typeIds for the element names.
	Result can then be validated with CFH schemas (must be done as a separate step).

	A lot of the work is to re-order the XML from CDA schema order
	to the order of the current schema generator in use by CFH.

	Usage : transform CDA xml using this file and an XSLT engine.
	Set parameter sSchemaFileNameWithoutPath to the message type to
	validate against.
	For details see comment against 'sSchemaFileNameWithoutPath' below.

	Rik Smithies 21/02/07 v0.4
	Updated Tim Ireland 26/02/08 v0.5
-->
<!-- Entities for constants so can use them in match expressions -->
<!DOCTYPE xsl:stylesheet [
	<!ENTITY templateOID "'2.16.840.1.113883.2.1.3.2.4.18.2'">
	<!ENTITY typeOID "'2.16.840.1.113883.1.3'">
]>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:h="urn:hl7-org:v3" exclude-result-prefixes="h" xmlns:npfitlc="NPFIT:HL7:Localisation">
	<xsl:output encoding="UTF-8"/>
	<xsl:output method="xml"/>
	<xsl:output indent="yes"/>
	<!-- kill the existing schema location, which will be replaced -->
	<xsl:template match="@*[local-name(.)='schemaLocation']"/>
	<!-- kill some implied attributes that we dont want to copy to output -->
	<xsl:template match="@type"/>
	<xsl:template match="@*[name(.)='integrityCheckAlgorithm']"/>
	<xsl:template match="@*[name(.)='mediaType']"/>
	<xsl:template match="@*[name(.)='representation']"/>
	<xsl:template match="@*[name(.)='operator']"/>
	<xsl:template match="@*[name(.)='inverted']"/>
	<xsl:template match="@*[name(.)='inclusive']"/>
	<xsl:template match="@*[name(.)='partType']"/>
	<!-- remove default attribute from CDA XML -->
	<!--<xsl:template match="@*[name(.)='listType']"/> -->
	
	<xsl:template match="h:ClinicalDocument">
		<xsl:variable name="sSchemaFileNameWithoutPath">
			<xsl:value-of select="npfitlc:messageType/@extension"/>
		</xsl:variable>
		<ClinicalDocument xmlns="urn:hl7-org:v3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:npfitlc="NPFIT:HL7:Localisation">
		<!--<xsl:element name="{name(.)}" xmlns="urn:hl7-org:v3" namespace="" xmlns:npfitlc="NPFIT:HL7:Localisation"> -->
			<xsl:attribute name="xsi:schemaLocation"><xsl:text>urn:hl7-org:v3 ..\..\Schemas\</xsl:text><xsl:value-of select="$sSchemaFileNameWithoutPath"/><xsl:text>.xsd</xsl:text></xsl:attribute>
			
			<xsl:call-template name="copyChildren"/>
	<!--	</xsl:element>-->
	</ClinicalDocument>
	</xsl:template>
	<xsl:template match="h:*[child::h:templateId]">
		<xsl:variable name="sNameFromXML">
			<xsl:value-of select="h:templateId/@extension"/>
		</xsl:variable>
		<!-- In CFH validation schemas elements at entry points to templates have artefact name prefix.
     These can be spotted by looking for the contentId above, which should match the templateId below -->
		<!-- initially just look for any templateId above here -->
		<xsl:variable name="sNameOfElement">
			<xsl:choose>
				<xsl:when test="../npfitlc:contentId">			
					<!-- want artefact in the name -->
					<xsl:value-of select="translate($sNameFromXML,'#','.')"/>
				</xsl:when>
				<xsl:otherwise>
					<!-- dont want artefact in the name -->
					<xsl:choose>
						<xsl:when test="contains($sNameFromXML,'#')">
							<xsl:value-of select="substring-after(h:templateId/@extension,'#')"/>
						</xsl:when>
						<xsl:otherwise>
							<!-- this shouldnt ever happen -->
							<xsl:comment> Warning : Unexpected typeId format </xsl:comment>
							<xsl:value-of select="$sNameFromXML"/>
						</xsl:otherwise>
					</xsl:choose>
				</xsl:otherwise>
			</xsl:choose>
		</xsl:variable>
		<!-- Catch some special case ones due to bugs in validation schemas (possibly fixed now) -->
		<xsl:variable name="aliasedName">
			<xsl:choose>
				<!-- none currently (or typeId being inserted on the fly) -->
				<!--xsl:when test="h:typeId/@extension='COTM_MT146005UK01#Location'">location</xsl:when-->
				<xsl:when test="false()">h:debug</xsl:when>
				<xsl:otherwise>
					<xsl:value-of select="$sNameOfElement"/>
				</xsl:otherwise>
			</xsl:choose>
		</xsl:variable>
		<xsl:element name="{$aliasedName}" namespace="urn:hl7-org:v3">
			<xsl:call-template name="copyChildren"/>
		</xsl:element>
	</xsl:template>
	<!-- copy all non-root elements unless overridden elsewhere -->
	<xsl:template match="*|node()">
		<xsl:copy>
			<xsl:call-template name="copyChildren"/>
		</xsl:copy>
	</xsl:template>
	
	<xsl:template match="@*">
			<xsl:copy>
			</xsl:copy>
		</xsl:template>
		
	<xsl:template match="@*[name(.)='xsi:type' and not(contains(parent::node()/preceding-sibling::h:templateId/@extension,'Finding') or contains(parent::node()/preceding-sibling::h:templateId/@extension,'Diagnosis') or contains(parent::node()/preceding-sibling::h:templateId/@extension,'LifeStyle') or contains(parent::node()/preceding-sibling::h:templateId/@extension,'SocialOrPersonalCircumstance'))]">
</xsl:template>
	<!-- general template to copy all children making some generic changes -->
	<xsl:template name="copyChildren">
		<xsl:param name="bNoAttributes" select="false()"/>
		<!-- copy attributes, must come before elements -->
		<xsl:if test="not($bNoAttributes)">
			<xsl:apply-templates select="@*"/>
			<!-- TJI -->
			<!-- ('COCD_TP146001UK02#LifeStyle' or 'COCD_TP146011UK02#Diagnosis' or 'COCD_TP146012UK02#Finding' ))  -->
		</xsl:if>
		<xsl:call-template name="copyInCFHCDAOrder"/>
		<xsl:call-template name="copyChildrenExcluding"/>
	</xsl:template>
	<xsl:template name="copyInCFHCDAOrder">
		<!-- copy attributes in a different CDA specific order -->
		<!-- not all of these are allowed on all CDA classes of course -->
		<!-- NB when adding to here also add to copyChildrenExcluding -->
		<!-- Seems no easy way to do this with a sort. Something like the following is
		 almost right, but it also sorts date types eg high/low into low/high -->
		<!--xsl:apply-templates select="node()[not(@typeCode)][not(@classCode)]">
		<xsl:sort select="local-name()"/>
	</xsl:apply-templates-->
		<!-- todo may be possible to group these by parent type eg acts first,
		 participations etc -->
		<xsl:apply-templates select="h:addr" mode="no_ns_hl7"/>
		<xsl:apply-templates select="h:code" mode="no_ns_hl7"/>
		<xsl:apply-templates select="h:confidentialityCode" mode="no_ns_hl7"/>
		<xsl:apply-templates select="npfitlc:contentId" mode="no_ns_cfh"/>
		<xsl:apply-templates select="h:desc" mode="no_ns_hl7"/>
		<xsl:apply-templates select="h:dischargeDispositionCode" mode="no_ns_hl7"/>
		<xsl:apply-templates select="h:effectiveTime" mode="no_ns_hl7"/>
		<xsl:apply-templates select="h:expectedUseTime" mode="no_ns_hl7"/>
		<xsl:apply-templates select="h:functionCode" mode="no_ns_hl7"/>
		<xsl:apply-templates select="h:id" mode="no_ns_hl7"/>
		<xsl:apply-templates select="h:interpretationCode" mode="no_ns_hl7"/>
		<xsl:apply-templates select="h:languageCode" mode="no_ns_hl7"/>
		<xsl:apply-templates select="h:modeCode" mode="no_ns_hl7"/>
		<xsl:apply-templates select="h:manufacturerModelName" mode="no_ns_hl7"/>
		<xsl:apply-templates select="npfitlc:messageType" mode="no_ns_cfh"/>
		<xsl:apply-templates select="h:name" mode="no_ns_hl7"/>
		<xsl:apply-templates select="h:quantity" mode="no_ns_hl7"/>
		<xsl:apply-templates select="npfitlc:recipientRoleCode" mode="no_ns_cfh"/>
		<xsl:apply-templates select="h:repeatNumber" mode="no_ns_hl7"/>
		<xsl:apply-templates select="h:seperatableInd" mode="no_ns_hl7"/>
		<xsl:apply-templates select="h:sequenceNumber" mode="no_ns_hl7"/>
		<xsl:apply-templates select="h:setId" mode="no_ns_hl7"/>
		<xsl:apply-templates select="h:signatureCode" mode="no_ns_hl7"/>
		<xsl:apply-templates select="h:softwareName" mode="no_ns_hl7"/>
		<xsl:apply-templates select="h:standardIndustryClassCode" mode="no_ns_hl7"/>
		<xsl:apply-templates select="h:statusCode" mode="no_ns_hl7"/>
		<xsl:apply-templates select="h:telecom" mode="no_ns_hl7"/>
		<xsl:apply-templates select="h:templateId" mode="no_ns_hl7"/>
		<xsl:apply-templates select="h:text" mode="no_ns_hl7"/>
		<xsl:apply-templates select="h:title" mode="no_ns_hl7"/>
		<xsl:apply-templates select="h:time" mode="no_ns_hl7"/>
		<xsl:apply-templates select="h:typeId" mode="no_ns_hl7"/>
		<xsl:apply-templates select="h:value" mode="no_ns_hl7"/>
		<xsl:apply-templates select="h:versionNumber" mode="no_ns_hl7"/>
		<!-- elements -->
		<!--xsl:call-template name="selectChildClasses"/-->
		<xsl:apply-templates select="*[@typeCode]">
			<!-- this complicated expression selects the typeId extension if there is one
			 otherwise selects the local-name.  -->
			<xsl:sort select="substring-before(substring-after(concat(h:templateId/@extension,'  #',local-name(),' '),'#'),' ')"/>
		</xsl:apply-templates>
	</xsl:template>
	<xsl:template mode="no_ns_hl7" match="*">
		<xsl:element name="{name(.)}" namespace="urn:hl7-org:v3">
			<xsl:for-each select="@*">
				<xsl:choose>
					<xsl:when test="name(.)='xsi:type' and ../@codeSystem='2.16.840.1.113883.2.1.3.2.4.17.106'"/>
					<xsl:when test="name(.)='xsi:type' and ../@codeSystem='2.16.840.1.113883.2.1.3.2.4.17.185'"/>
					<xsl:when test="name(.)='xsi:type' and ../@codeSystem='2.16.840.1.113883.2.1.3.2.4.17.160'"/>
					<xsl:when test="name(.)='xsi:type' and .='BL'"/>
					<xsl:when test="name(.)='xsi:type' and .='TS'"/>
					<xsl:when test="name(.)='xsi:type' and .='IVL_TS'"/>
					<xsl:when test="name(.)='xsi:type' and .='CV.NPfIT.CDA.Url'"/>
					<xsl:when test="name(.)='xsi:type' and .='CD.NPfIT.CDA.Url'"/>
					<xsl:when test="name(.)='xsi:type' and .='CE.NPfIT.CDA.Url'"/>
					<xsl:when test="not(contains(.,'xmlns'))">
						<xsl:copy-of select="."/>
					</xsl:when>
				</xsl:choose>
			</xsl:for-each>
			<xsl:apply-templates mode="no_ns_hl7" select="node()"/>
		</xsl:element>
	</xsl:template>
	<xsl:template mode="no_ns_cfh" match="*">
		<xsl:element name="{name(.)}" namespace="NPFIT:HL7:Localisation">
			<xsl:for-each select="@*">
				<xsl:if test="not(contains(.,'xmlns'))">
					<xsl:copy-of select="."/>
				</xsl:if>
			</xsl:for-each>
			<xsl:apply-templates mode="no_ns_cfh" select="node()"/>
		</xsl:element>
	</xsl:template>
	<!-- unused at moment -->
	<xsl:template match="*[@typeCode]" mode="addComment">
		<!-- can add a debug comment into output here, when debugging sort order -->
		<!--xsl:comment>
		concat <xsl:value-of select="concat(h:typeId/@extension,' #',local-name(),' ')"/> !
		after # <xsl:value-of select="substring-after(concat(h:typeId/@extension,' #',local-name(),' '),'#')"/> !
		before space <xsl:value-of select="substring-before(substring-after(concat(h:typeId/@extension,' #',local-name(),' '),'#'),' ')"/>
	</xsl:comment-->
		<xsl:apply-templates select="."/>
	</xsl:template>
	<xsl:template name="copyChildrenExcluding">
		<!-- purpose of this is to "fail safe", in that everything
	     not specifically mentioned in copyInCFHCDAOrder will get copied.
       	 So nothing new or unconsidered can get forgotten.
       	 Until codes are added here they may get copied twice, which will
       	 be noticed at schema validation. -->
		<!-- exclude the attributes already known to be copied.
 		 All RIM attributes in use need to be named -->
		<xsl:apply-templates select="node()
								[not(self::*[@typeCode])]
								[not(self::h:typeId)]
								[not(self::h:standardIndustryClassCode)]
								[not(self::npfitlc:contentId)]
								[not(self::npfitlc:messageType)]
								[not(self::npfitlc:recipientRoleCode)]
								[not(self::h:telecom)]
								[not(self::h:interpretationCode)]
								[not(self::h:id)]
								[not(self::h:dischargeDispositionCode)]
								[not(self::h:languageCode)]
								[not(self::npfitlc:messageType)]
								[not(self::h:seperatableInd)]
								[not(self::h:sequenceNumber)]
								[not(self::h:functionCode)]
								[not(self::h:templateId)]
								[not(self::h:addr)]
								[not(self::h:code)]
								[not(self::h:desc)]
								[not(self::h:statusCode)]
								[not(self::h:effectiveTime)]
								[not(self::h:confidentialityCode)]
								[not(self::h:expectedUseTime)]
								[not(self::h:setId)]
								[not(self::h:signatureCode)]
								[not(self::h:title)]
								[not(self::h:text)]
								[not(self::h:time)]
								[not(self::h:name)]
								[not(self::h:quantity)]
								[not(self::h:repeatNumber)]
								[not(self::h:value)]
								[not(self::h:product)]
								[not(self::h:versionNumber)]
								[not(self::h:manufacturerModelName)]
								[not(self::h:softwareName)]
								[not(self::h:modeCode)]"/>
	</xsl:template>
	<!-- Special case fixes to remove particular usageas of xsi:type, a peculiarity of CFH validation schemas -->
	<xsl:template match="@xsi:type[.='CV'][../@codeSystem='2.16.840.1.113883.2.1.3.2.4.17.106']">
</xsl:template>
	<xsl:template match="@xsi:type[.='CV'][../@codeSystem='2.16.840.1.113883.2.1.3.2.4.17.185']">
</xsl:template>
	<xsl:template match="@xsi:type[.='CV'][../@codeSystem='2.16.840.1.113883.2.1.3.2.4.17.160']">
</xsl:template>
	<xsl:template match="@xsi:type[.='BL']">
</xsl:template>
	
	<!-- MODEL ERROR FIXES, All to be removed ultimately (todo) -->
	<!-- remove some things added in transform to CDA as workarounds, that are not template schema valid -->
	<!--<xsl:template match="*[@typeCode='AUTHEN' or @typeCode='LA' or @typeCode='ENT']/h:time"/>
<xsl:template match="*[@typeCode='AUTHEN' or @typeCode='LA' or @typeCode='ENT']/h:signatureCode"/>

<xsl:template match="*[@classCode='ASSIGNED']
						[../@typeCode='AUTHEN' or ../@typeCode='LA' or ../@typeCode='ENT'
							or ../@typeCode='INF']/h:id[../h:code]">
	 this will have been added on the fly as a workaround to model issue, needs stripping 
</xsl:template> -->
	<!-- THIS IS A WORKAROUND FOR BUG IN TRC IN REQUESTMEDSUPPLY -->
	<!--<xsl:template match="*[@typeCode='TRC']/@contextControlCode">
		<xsl:attribute name="contextControlCode">ON</xsl:attribute>
	</xsl:template>-->
	<!-- workaround for forced typeId needed but not template valid -->
	<!-- <xsl:template match="*[@typeCode='TRC']/*[@classCode='ASSIGNED']/*[@classCode='PSN']/h:typeId"/> -->
	<!-- workaround for forced contextControlCode -->
	<!-- <xsl:template match="h:dataEnterer/@contextControlCode"/>-->
	<!-- kill dummy typeId - may be overkill but wont hurt for temp usage -->
	
	<!-- workaround for broken performer as generic participant contextControlCode -->
	<!--<xsl:template match="h:participant[@typeCode='PRF']/@contextControlCode"/>-->
	<!-- <xsl:template match="h:participant[@typeCode='SPRF']/@contextControlCode"/>-->
	<!-- reinsert removed desc (Now resolved) -->
	<!--xsl:template match="*[@typeCode='INF']/*[@classCode='ASSIGNED']/*[@classCode='ORG']/h:id" priority="99">

	<xsl:comment> FIX desc reinserted since templates need it but CDA doesnt have it </xsl:comment>
	<desc xmlns="urn:hl7-org:v3">WARNING dummy description</desc>
	<id xmlns="urn:hl7-org:v3">
		<xsl:call-template name="copyChildren"/>
	</id>

</xsl:template-->
	<!-- wrong typeId case in <typeId root="2.16.840.1.113883.1.3" extension="COCD_TP146005UK01#Location" -->
	<xsl:template match="@extension[.='COCD_TP146005UK01#location']">
		<xsl:attribute name="extension">COCD_TP146005UK01#Location</xsl:attribute>
	</xsl:template>
	<xsl:template match="@extension[.='COCD_TP146031UK01#location']">
		<xsl:attribute name="extension">COCD_TP146031UK01#Location</xsl:attribute>
	</xsl:template>
	<!-- kill dummy statusCode that needed adding til model fixed todo -->
	<!-- this will also remove non-act ref ones so is very temporary -->
	<xsl:template match="h:organizer[count(*)=4 and h:code/@nullFlavor]/h:statusCode">
		<xsl:comment> removed statusCode </xsl:comment>
	</xsl:template>

	<xsl:template match="h:id[@extension='dummyid']"/>
	<!-- workaround for missing typeId -->
	<xsl:template match="h:participant[@typeCode='SPRF']/h:participantRole[@classCode='ASSIGNED']/h:playingEntity[@classCode='PSN']">
		<assignedPerson xmlns="urn:hl7-org:v3">
			<xsl:call-template name="copyChildren"/>
		</assignedPerson>
	</xsl:template>

	<xsl:template match="h:parentDocument">
		<priorParentDocument xmlns="urn:hl7-org:v3">
			<xsl:call-template name="copyChildren"/>
		</priorParentDocument>
	</xsl:template>

	<xsl:template match="*[@typeCode='DEV' and h:*/@classCode='ROL']">
		<participant xmlns="urn:hl7-org:v3">
			<xsl:call-template name="copyChildren"/>
		</participant>
	</xsl:template>
	<!-- TJI classificationSection fix -->
	<xsl:template match="h:*[@classCode='DOCSECT' ][../../@classCode='DOCBODY']">
		<!-- and contains(local-name(../../),'structuredBody')]">-->
		<classificationSection xmlns="urn:hl7-org:v3">
			<xsl:call-template name="copyChildren"/>
		</classificationSection>
	</xsl:template>
	<!-- TJI entry1 fix -->
	<xsl:template match="h:entry[contains(npfitlc:contentId/@extension,'CRETypeList')]">
		<entry1 xmlns="urn:hl7-org:v3">
			<xsl:call-template name="copyChildren"/>
		</entry1>
	</xsl:template>
	<!-- todo tji fix for tracker -->
	<xsl:template match="h:informationRecipient[@typeCode='TRC']">
		<tracker xmlns="urn:hl7-org:v3">
			<xsl:call-template name="copyChildren"/>
		</tracker>
	</xsl:template>
	<xsl:template match="comment()">
	</xsl:template>
	<!-- TJI cREType fix 
<xsl:template match="//h:observation[local-name(..)='entry' and not(../npfitlc:contentId)]">
<cREType  xmlns="urn:hl7-org:v3">
	 <xsl:call-template name="copyChildren"/>
</cREType>
</xsl:template>-->
	<!-- a comment based way to workaround removed items. This code shouldnt be used
 	 in production, its only for modelling issue workarounds -->
	<!-- element reordering makes this an unhelpful approach -->
	<!--xsl:template match="comment()" priority="99">
	<xsl:choose>
		<xsl:when test="contains(., 'REINSERT desc')">
			<xsl:copy-of select="."/>
			<desc xmlns="urn:hl7-org:v3">WARNING actual desc removed</desc>
		</xsl:when>
		<xsl:otherwise>
			<xsl:copy-of select="."/>
		</xsl:otherwise>
	</xsl:choose>
</xsl:template-->
	<!-- general utilities -->
	<xsl:template name="replace">
		<xsl:param name="string" select="''"/>
		<xsl:param name="pattern" select="''"/>
		<xsl:param name="replacement" select="''"/>
		<xsl:choose>
			<xsl:when test="$pattern != '' and $string != '' and contains($string, $pattern)">
				<xsl:value-of select="substring-before($string, $pattern)"/>
				<!-- Use "xsl:copy-of" instead of "xsl:value-of" so that can substitute nodes as well as strings -->
				<xsl:copy-of select="$replacement"/>
				<xsl:call-template name="replace">
					<xsl:with-param name="string" select="substring-after($string, $pattern)"/>
					<xsl:with-param name="pattern" select="$pattern"/>
					<xsl:with-param name="replacement" select="$replacement"/>
				</xsl:call-template>
			</xsl:when>
			<xsl:otherwise>
				<xsl:value-of select="$string"/>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>
</xsl:stylesheet>
