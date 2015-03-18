/*
Navicat MySQL Data Transfer

Source Server         : localhost
Source Server Version : 50524
Source Host           : localhost:3306
Source Database       : inventory

Target Server Type    : MYSQL
Target Server Version : 50524
File Encoding         : 65001

Date: 2015-03-18 12:06:42
*/

SET FOREIGN_KEY_CHECKS=0;

-- ----------------------------
-- Table structure for actions
-- ----------------------------
DROP TABLE IF EXISTS `actions`;
CREATE TABLE `actions` (
  `ActionID` int(11) NOT NULL AUTO_INCREMENT,
  `UsesType` int(11) NOT NULL,
  `ActionName` varchar(255) NOT NULL DEFAULT 'None',
  PRIMARY KEY (`ActionID`)
) ENGINE=InnoDB AUTO_INCREMENT=23 DEFAULT CHARSET=latin1;

-- ----------------------------
-- Records of actions
-- ----------------------------
INSERT INTO `actions` VALUES ('1', '-1', 'Swap');
INSERT INTO `actions` VALUES ('2', '-1', 'Add into');
INSERT INTO `actions` VALUES ('5', '4', 'Take Medicine');
INSERT INTO `actions` VALUES ('6', '5', 'Eat All Food');
INSERT INTO `actions` VALUES ('7', '5', 'Eat Food');
INSERT INTO `actions` VALUES ('8', '6', 'Empty Magazine');
INSERT INTO `actions` VALUES ('10', '7', 'Split');
INSERT INTO `actions` VALUES ('12', '6', 'Check Ammo');
INSERT INTO `actions` VALUES ('13', '-2', 'Combine');
INSERT INTO `actions` VALUES ('14', '-2', 'Swap');
INSERT INTO `actions` VALUES ('15', '2', 'Empty Gun');
INSERT INTO `actions` VALUES ('16', '12', 'Empty Bolt Gun');
INSERT INTO `actions` VALUES ('17', '2', 'Check Magazine');
INSERT INTO `actions` VALUES ('18', '12', 'Check Inside Chamber');
INSERT INTO `actions` VALUES ('19', '-3', 'Swap Container');
INSERT INTO `actions` VALUES ('20', '-3', 'Add Into Container');

-- ----------------------------
-- Table structure for objectinventory
-- ----------------------------
DROP TABLE IF EXISTS `objectinventory`;
CREATE TABLE `objectinventory` (
  `InventoryID` int(11) NOT NULL AUTO_INCREMENT,
  `PlayerObjectID` int(11) NOT NULL,
  `InsideIDs` varchar(64) NOT NULL DEFAULT '',
  PRIMARY KEY (`InventoryID`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- ----------------------------
-- Records of objectinventory
-- ----------------------------

-- ----------------------------
-- Table structure for objects
-- ----------------------------
DROP TABLE IF EXISTS `objects`;
CREATE TABLE `objects` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `Name` varchar(64) NOT NULL DEFAULT 'New_Object',
  `Size` int(11) NOT NULL DEFAULT '1',
  `UsesType` int(11) NOT NULL DEFAULT '10',
  `UsesSlot` int(3) DEFAULT '1',
  `SlotsInside` int(11) DEFAULT '0',
  `Weight` float DEFAULT '0',
  `MaxUses` int(11) NOT NULL DEFAULT '0',
  `Display` int(11) NOT NULL DEFAULT '19999',
  `DisplayColor` bigint(24) DEFAULT '-1' COMMENT 'Color as integer',
  `DisplayOffsets` varchar(60) DEFAULT '0.0,0.0,0.0,1.0' COMMENT 'X,Y,Z, Zoom',
  `OnHandOffsets` varchar(60) DEFAULT '0.0,0.0,0.0,0.0,0.0,0.0' COMMENT 'X,Y,Z RX,RY,RZ SX,SY,SZ',
  `OnBodyOffsets` varchar(60) DEFAULT '0,0.0,0.0,0.0,0.0,0.0,0.0' COMMENT 'Bone, X,Y,Z, RX,RY,RZ, SX, SY, SZ',
  `ObjectScales` varchar(30) DEFAULT '1.0,1.0,1.0',
  `SpecialFlag_1` int(11) DEFAULT '0',
  `SpecialFlag_2` int(11) DEFAULT '0',
  `SpecialFlag_3` int(11) DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB AUTO_INCREMENT=47 DEFAULT CHARSET=latin1;

-- ----------------------------
-- Records of objects
-- ----------------------------
INSERT INTO `objects` VALUES ('1', 'Briefcase', '15', '1', '4', '18', '0', '0', '1210', '269488383', '0.000,45.000,0.000,1.500', '0.324,0.144,-0.065,0.200,-71.098,-5.499', '1,0.082,-0.075,0.000,-8.100,1.998,0.000', '1.000,1.730,1.174', '0', '0', '0');
INSERT INTO `objects` VALUES ('3', 'Chainsaw', '5', '12', '5', '1', '0', '0', '341', '-1', '0.0,180.0,90.0,1.5', '0.0,0.0,0.0,0.0,0.0,0.0', '1,-0.256,-0.138,-0.139,-4.399,13.600,-10.800', '1.000,1.000,1.000', '9', '69', '1');
INSERT INTO `objects` VALUES ('4', 'Pill', '1', '4', '8', '0', '0', '2', '1241', '-1', '0.0,0.0,0.0,1.0', '0.0,0.0,0.0,0.0,0.0,0.0', '0,0.0,0.0,0.0,0.0,0.0,0.0', '1.0,1.0,1.0', '1', '0', '0');
INSERT INTO `objects` VALUES ('5', 'Combat Armor', '3', '3', '9', '6', '0', '100', '1242', '1180321791', '0.000,0.000,0.000,0.800', '0.0,0.0,0.0,0.0,0.0,0.0', '1,0.065,0.031,0.012,-8.199,89.800,-2.000', '1.548,2.069,1.588', '0', '0', '0');
INSERT INTO `objects` VALUES ('6', 'Very Big Case', '25', '8', '4', '35', '0', '0', '1210', '-1', '0.0,0.0,0.0,1.0', '0.0,0.0,0.0,0.0,0.0,0.0', '0,0.0,0.0,0.0,0.0,0.0,0.0', '1.0,1.0,1.0', '0', '0', '0');
INSERT INTO `objects` VALUES ('7', 'Combat Shotgun', '10', '12', '5', '1', '0', '0', '351', '-1', '0.0,45.0,0.0,2.0', '0.0,0.0,0.0,0.0,0.0,0.0', '1,-0.079,-0.152,-0.123,-165.499,21.499,-6.099', '1.000,1.000,1.000', '27', '2', '7');
INSERT INTO `objects` VALUES ('8', 'Can Of Beans', '1', '5', '8', '0', '0', '4', '1217', '-1', '0.000,0.000,0.000,2.000', '0.089,0.073,-0.037,0.000,0.000,0.000', '11,-0.364,-0.287,0.027,0.000,0.000,0.000', '0.159,0.140,0.148', '1', '0', '0');
INSERT INTO `objects` VALUES ('10', 'Pellets', '1', '7', '8', '0', '0', '12', '2061', '-1728052993', '0.0,0.0,0.0,1.0', '0.120,0.059,0.000,0.000,0.000,0.000', '0,0.0,0.0,0.0,0.0,0.0,0.0', '0.294,0.369,0.194', '2', '0', '0');
INSERT INTO `objects` VALUES ('11', '7.62x39mm', '1', '7', '8', '0', '0', '60', '2061', '-1', '0.0,0.0,0.0,1.0', '0.0,0.0,0.0,0.0,0.0,0.0', '0,0.0,0.0,0.0,0.0,0.0,0.0', '1.0,1.0,1.0', '1', '0', '0');
INSERT INTO `objects` VALUES ('12', 'Mag 7.62x39mm', '2', '6', '8', '1', '0', '0', '2043', '-10092289', '0.000,91.000,90.000,1.200', '0.099,0.061,0.014,15.700,42.900,45.299', '0,0.0,0.0,0.0,0.0,0.0,0.0', '0.592,0.120,0.839', '1', '30', '0');
INSERT INTO `objects` VALUES ('13', 'AK47', '10', '2', '5', '2', '0', '0', '355', '-1', '0.0,0.0,0.0,2.0', '0.0,0.0,0.0,0.0,0.0,0.0', '1,-0.029,-0.101,0.228,176.101,1.998,1.095', '1.000,1.000,1.000', '30', '1', '0');
INSERT INTO `objects` VALUES ('18', 'Sawn Off Shotgun', '8', '12', '7', '1', '0', '0', '350', '-1', '0.0,0.0,0.0,1.0', '0.0,0.0,0.0,0.0,0.0,0.0', '0,0.0,0.0,0.0,0.0,0.0,0.0', '1.0,1.0,1.0', '26', '2', '2');
INSERT INTO `objects` VALUES ('19', 'Pistol', '5', '2', '7', '1', '0', '0', '346', '-1', '0.0,0.0,0.0,1.0', '0.0,0.0,0.0,0.0,0.0,0.0', '8,-0.078,-0.020,0.103,-111.299,13.400,-19.399', '1.029,1.033,1.098', '22', '3', '0');
INSERT INTO `objects` VALUES ('20', 'Mag 9x19mm', '1', '6', '8', '1', '0', '0', '2043', '-1', '0.000,110.000,90.000,1.400', '0.119,0.060,0.000,0.000,0.000,0.000', '0,0.0,0.0,0.0,0.0,0.0,0.0', '0.298,0.084,0.542', '3', '0', '0');
INSERT INTO `objects` VALUES ('22', '9x19mm Round', '1', '7', '8', '0', '0', '15', '2061', '-1', '0.0,0.0,0.0,1.9', '0.127,0.041,0.000,-4.798,2.398,0.000', '0,0.0,0.0,0.0,0.0,0.0,0.0', '0.167,0.203,0.173', '3', '0', '0');
INSERT INTO `objects` VALUES ('23', 'Ammo Box', '4', '11', '6', '6', '0', '0', '2043', '5570815', '0.0,0.0,90.0,1.0', '0.0,0.0,0.0,0.0,0.0,0.0', '0,0.0,0.0,0.0,0.0,0.0,0.0', '1.0,1.0,1.0', '0', '0', '0');
INSERT INTO `objects` VALUES ('24', 'Pump Action Shotgun', '5', '12', '5', '1', '0', '0', '349', '-1', '180.000,225.000,0.000,1.700', '0.000,-0.003,-0.000,0.000,0.000,0.000', '1,-0.193,-0.120,0.143,6.200,14.399,0.000', '1.009,1.256,1.029', '25', '2', '6');
INSERT INTO `objects` VALUES ('25', 'Country Rifle', '10', '12', '5', '1', '0', '0', '357', '-1', '0.0,0.0,0.0,1.0', '0.0,0.0,0.0,0.0,0.0,0.0', '0,0.0,0.0,0.0,0.0,0.0,0.0', '1.0,1.0,1.0', '33', '4', '0');
INSERT INTO `objects` VALUES ('26', '7.62x51mm', '1', '7', '8', '0', '0', '30', '2061', '-1', '0.0,0.0,0.0,0.8', '0.0,0.0,0.0,0.0,0.0,0.0', '0,0.0,0.0,0.0,0.0,0.0,0.0', '0.956,1.000,0.535', '4', '0', '0');
INSERT INTO `objects` VALUES ('27', 'Sniper Rifle', '10', '12', '5', '1', '0', '0', '358', '-1', '0.000,0.000,0.000,1.800', '0.0,0.0,0.0,0.0,0.0,0.0', '1,0.075,-0.141,0.038,19.100,17.699,19.199', '1.000,1.000,1.000', '34', '4', '10');
INSERT INTO `objects` VALUES ('28', 'Chainsaw Fuel', '1', '7', '8', '0', '0', '1', '1650', '-1', '0.0,0.0,0.0,1.0', '0.0,0.0,0.0,0.0,0.0,0.0', '0,0.0,0.0,0.0,0.0,0.0,0.0', '1.0,1.0,1.0', '69', '0', '0');
INSERT INTO `objects` VALUES ('29', 'Mountain Backpack', '28', '1', '4', '30', '0', '0', '371', '-1', '0.000,0.000,0.000,0.700', '0.0,0.0,0.0,0.0,0.0,0.0', '1,0.063,-0.126,-0.008,-1.799,90.197,0.000', '1.326,1.194,1.556', '0', '0', '0');
INSERT INTO `objects` VALUES ('30', 'Deagle', '6', '2', '7', '1', '0', '0', '348', '-1', '0.000,0.000,0.000,1.500', '0.0,0.0,0.0,0.0,0.0,0.0', '7,-0.074,-0.052,-0.101,-72.999,0.800,9.300', '1.000,1.000,1.000', '24', '5', '0');
INSERT INTO `objects` VALUES ('31', '.45 ACP Mag', '1', '6', '8', '1', '0', '0', '2043', '-2004317953', '0.000,110.000,90.000,1.300', '0.0,0.0,0.0,0.0,0.0,0.0', '0,0.0,0.0,0.0,0.0,0.0,0.0', '1.0,1.0,1.0', '5', '14', '0');
INSERT INTO `objects` VALUES ('32', '.45 ACP Rounds', '1', '7', '8', '0', '0', '30', '2061', '-1717986817', '0.000,0.000,0.000,1.650', '0.0,0.0,0.0,0.0,0.0,0.0', '6,0.000,0.000,0.000,0.000,0.000,0.000', '1.000,1.000,1.000', '5', '0', '0');
INSERT INTO `objects` VALUES ('37', 'Small 7.62x39mm Mag', '2', '6', '8', '1', '0', '0', '2043', '-10092289', '0.000,91.000,90.000,1.500', '0.099,0.061,0.014,15.700,42.900,45.299', '0,0.000,0.000,0.000,0.000,0.000,0.000', '0.592,0.120,0.839', '1', '20', '0');
INSERT INTO `objects` VALUES ('38', 'Big 7.62x39mm Mag', '2', '6', '8', '1', '0', '0', '2043', '-10092289', '0.000,91.000,90.000,1.000', '0.099,0.061,0.014,15.700,42.900,45.299', '0,0.000,0.000,0.000,0.000,0.000,0.000', '0.592,0.120,0.839', '1', '50', '0');
INSERT INTO `objects` VALUES ('39', '5.56x51mm NATO_', '1', '7', '8', '0', '0', '60', '2061', '-1', '0.000,0.000,0.000,1.300', '0.000,0.000,0.000,0.000,0.000,0.000', '0,0.000,0.000,0.000,0.000,0.000,0.000', '1.000,1.000,1.000', '6', '0', '0');
INSERT INTO `objects` VALUES ('40', 'Mag 5.56x45mm NATO', '2', '6', '8', '1', '0', '0', '2043', '-1145324545', '0.000,91.000,90.000,0.900', '0.099,0.061,0.014,15.700,42.900,45.299', '0,0.000,0.000,0.000,0.000,0.000,0.000', '0.592,0.120,0.839', '6', '30', '0');
INSERT INTO `objects` VALUES ('41', 'M4A1', '10', '2', '5', '2', '0', '0', '356', '-1', '0.000,0.000,0.000,2.000', '0.000,0.000,0.000,0.000,0.000,0.000', '1,-0.003,-0.136,0.127,163.899,-27.701,-4.905', '1.000,1.000,1.000', '31', '6', '0');
INSERT INTO `objects` VALUES ('42', 'Silenced Pistol', '5', '2', '7', '1', '0', '0', '347', '-1', '0.000,0.000,0.000,1.000', '0.000,0.000,0.000,0.000,0.000,0.000', '8,-0.078,-0.021,0.103,-111.299,13.400,-19.399', '1.029,1.034,1.098', '23', '7', '0');
INSERT INTO `objects` VALUES ('43', '9x19mm SD Round', '1', '7', '8', '0', '0', '30', '2061', '-1', '0.000,0.000,0.000,1.600', '0.000,0.000,0.000,0.000,0.000,0.000', '0,0.000,0.000,0.000,0.000,0.000,0.000', '1.000,1.000,1.000', '7', '0', '0');
INSERT INTO `objects` VALUES ('44', 'Mag 9x19mm SD', '1', '6', '8', '1', '0', '0', '2043', '-1', '0.000,110.000,90.000,1.400', '0.119,0.060,0.000,0.000,0.000,0.000', '0,0.000,0.000,0.000,0.000,0.000,0.000', '0.298,0.084,0.542', '7', '7', '0');
INSERT INTO `objects` VALUES ('45', 'Knife', '2', '9', '1', '0', '0', '0', '19999', '-1', '0.0,0.0,0.0,1.0', '0.0,0.0,0.0,0.0,0.0,0.0', '0,0.0,0.0,0.0,0.0,0.0,0.0', '1.0,1.0,1.0', '0', '0', '0');
INSERT INTO `objects` VALUES ('46', 'Purple Dildo', '3', '9', '8', '0', '0', '0', '321', '-1', '0.0,0.0,0.0,1.0', '0.0,0.0,0.0,0.0,0.0,0.0', '0,0.0,0.0,0.0,0.0,0.0,0.0', '1.0,1.0,1.0', '10', '0', '0');

-- ----------------------------
-- Table structure for playerinventories
-- ----------------------------
DROP TABLE IF EXISTS `playerinventories`;
CREATE TABLE `playerinventories` (
  `PlayerName` varchar(24) NOT NULL,
  `4` int(5) DEFAULT NULL,
  `5` int(5) DEFAULT NULL,
  `6` int(5) DEFAULT NULL,
  `7` int(5) DEFAULT NULL,
  `8` int(5) DEFAULT NULL,
  `9` int(5) DEFAULT NULL,
  PRIMARY KEY (`PlayerName`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- ----------------------------
-- Records of playerinventories
-- ----------------------------

-- ----------------------------
-- Table structure for playerobjects
-- ----------------------------
DROP TABLE IF EXISTS `playerobjects`;
CREATE TABLE `playerobjects` (
  `PlayerID` int(11) NOT NULL AUTO_INCREMENT,
  `PlayerName` varchar(24) NOT NULL DEFAULT '',
  `BaseObjectID` int(11) NOT NULL DEFAULT '0',
  `CurrentUses` int(11) NOT NULL DEFAULT '0',
  `Position` int(11) NOT NULL DEFAULT '0',
  `Status` int(11) NOT NULL DEFAULT '0',
  `Condition` int(11) DEFAULT '3',
  `WorldX` float NOT NULL DEFAULT '0',
  `WorldY` float NOT NULL DEFAULT '0',
  `WorldZ` float NOT NULL DEFAULT '0',
  `P_SpecialFlag_1` int(11) DEFAULT '0',
  `P_SpecialFlag_2` int(11) DEFAULT '0',
  PRIMARY KEY (`PlayerID`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- ----------------------------
-- Records of playerobjects
-- ----------------------------

-- ----------------------------
-- Table structure for slots
-- ----------------------------
DROP TABLE IF EXISTS `slots`;
CREATE TABLE `slots` (
  `SlotID` int(11) NOT NULL AUTO_INCREMENT,
  `SlotName` varchar(32) NOT NULL,
  `MaxObjects` int(2) NOT NULL DEFAULT '1',
  PRIMARY KEY (`SlotID`)
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=latin1;

-- ----------------------------
-- Records of slots
-- ----------------------------
INSERT INTO `slots` VALUES ('1', 'Not Assigned', '1');
INSERT INTO `slots` VALUES ('4', 'Backpack', '2');
INSERT INTO `slots` VALUES ('5', 'Primary Weapon', '1');
INSERT INTO `slots` VALUES ('6', 'Ammo Box', '1');
INSERT INTO `slots` VALUES ('7', 'Side Gun', '2');
INSERT INTO `slots` VALUES ('8', 'Object', '0');
INSERT INTO `slots` VALUES ('9', 'Body Protection', '1');

-- ----------------------------
-- Table structure for types
-- ----------------------------
DROP TABLE IF EXISTS `types`;
CREATE TABLE `types` (
  `TypeID` int(11) NOT NULL AUTO_INCREMENT,
  `TypeName` varchar(64) NOT NULL,
  PRIMARY KEY (`TypeID`)
) ENGINE=InnoDB AUTO_INCREMENT=14 DEFAULT CHARSET=latin1;

-- ----------------------------
-- Records of types
-- ----------------------------
INSERT INTO `types` VALUES ('1', 'Container');
INSERT INTO `types` VALUES ('2', 'Weapon');
INSERT INTO `types` VALUES ('3', 'Body Armor');
INSERT INTO `types` VALUES ('4', 'Medicine');
INSERT INTO `types` VALUES ('5', 'Food');
INSERT INTO `types` VALUES ('6', 'Magazine');
INSERT INTO `types` VALUES ('7', 'Ammo');
INSERT INTO `types` VALUES ('8', 'Backpack');
INSERT INTO `types` VALUES ('9', 'Melee Weapon');
INSERT INTO `types` VALUES ('10', 'No Type');
INSERT INTO `types` VALUES ('11', 'Ammo Box');
INSERT INTO `types` VALUES ('12', 'Bolt Weapon');
INSERT INTO `types` VALUES ('13', 'Clothes');
