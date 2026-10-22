const fs = require('fs');

const newFields = [
  'Pedestal__c.X_Coordinate__c',
  'Pedestal__c.Y_Coordinate__c',
  'Pile__c.X_Coordinate__c',
  'Pile__c.Y_Coordinate__c',
  'Raft__c.Coordinates_JSON__c',
  'Raft__c.Number_of_Corners__c'
];

function updatePermissionSet(filePath, isEditable) {
  let content = fs.readFileSync(filePath, 'utf8');

  // 1. Add classAccesses if not present
  if (!content.includes('<apexClass>RaftCoordinateController</apexClass>')) {
    const classAccessXml = `    <classAccesses>
        <apexClass>RaftCoordinateController</apexClass>
        <enabled>true</enabled>
    </classAccesses>\n`;
    content = content.replace(/<description>/, classAccessXml + '    <description>');
  }

  // 2. Add fieldPermissions
  let fpXml = '';
  newFields.forEach(f => {
    if (!content.includes(`<field>${f}</field>`)) {
      fpXml += `    <fieldPermissions>
        <editable>${isEditable}</editable>
        <field>${f}</field>
        <readable>true</readable>
    </fieldPermissions>\n`;
    }
  });

  if (fpXml) {
    content = content.replace(/<hasActivationRequired>/, fpXml + '    <hasActivationRequired>');
  }

  fs.writeFileSync(filePath, content, 'utf8');
  console.log('Updated ' + filePath);
}

function updateAdminProfile(filePath) {
  let content = fs.readFileSync(filePath, 'utf8');

  // 1. Add classAccesses
  if (!content.includes('<apexClass>RaftCoordinateController</apexClass>')) {
    const classAccessXml = `    <classAccesses>
        <apexClass>RaftCoordinateController</apexClass>
        <enabled>true</enabled>
    </classAccesses>\n`;
    // Place right before <custom>
    content = content.replace(/<custom>/, classAccessXml + '    <custom>');
  }

  // 2. Add fieldPermissions
  let fpXml = '';
  newFields.forEach(f => {
    if (!content.includes(`<field>${f}</field>`)) {
      fpXml += `    <fieldPermissions>
        <editable>true</editable>
        <field>${f}</field>
        <readable>true</readable>
    </fieldPermissions>\n`;
    }
  });

  if (fpXml) {
    content = content.replace(/<objectPermissions>/, fpXml + '    <objectPermissions>');
  }

  fs.writeFileSync(filePath, content, 'utf8');
  console.log('Updated ' + filePath);
}

updatePermissionSet('force-app/main/default/permissionsets/Nirmaan_Project_Admin.permissionset-meta.xml', true);
updatePermissionSet('force-app/main/default/permissionsets/Nirmaan_Site_Engineer.permissionset-meta.xml', true);
updatePermissionSet('force-app/main/default/permissionsets/Nirmaan_Field_Supervisor.permissionset-meta.xml', false);
updateAdminProfile('force-app/main/default/profiles/Admin.profile-meta.xml');
