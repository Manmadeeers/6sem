const Sequelize = require('sequelize');
const { Model } = Sequelize;

class Faculty extends Model {}
class Pulpit extends Model {}
class Teacher extends Model {}
class Subject extends Model {}
class Auditorium_type extends Model {}
class Auditorium extends Model {}

function ORMhelper(seq) {
  Faculty.init(
    {
      faculty: { type: Sequelize.STRING, allowNull: false, primaryKey: true },
      faculty_name: { type: Sequelize.STRING, allowNull: false }
    },
    { sequelize: seq, modelName: 'Faculty', tableName: 'Faculty', timestamps: false }
  );

  Pulpit.init(
    {
      pulpit: { type: Sequelize.STRING, allowNull: false, primaryKey: true },
      pulpit_name: { type: Sequelize.STRING, allowNull: false },
      faculty: { type: Sequelize.STRING, allowNull: false, references: { model: Faculty, key: 'faculty' } }
    },
    { sequelize: seq, modelName: 'Pulpit', tableName: 'Pulpit', timestamps: false }
  );

  Teacher.init(
    {
      teacher: { type: Sequelize.STRING, allowNull: false, primaryKey: true },
      teacher_name: { type: Sequelize.STRING, allowNull: false },
      pulpit: { type: Sequelize.STRING, allowNull: false, references: { model: Pulpit, key: 'pulpit' } }
    },
    { sequelize: seq, modelName: 'Teacher', tableName: 'Teacher', timestamps: false }
  );

  Subject.init(
    {
      subject: { type: Sequelize.STRING, allowNull: false, primaryKey: true },
      subject_name: { type: Sequelize.STRING, allowNull: false },
      pulpit: { type: Sequelize.STRING, allowNull: false, references: { model: Pulpit, key: 'pulpit' } }
    },
    { sequelize: seq, modelName: 'Subject', tableName: 'Subject', timestamps: false }
  );

  Auditorium_type.init(
    {
      auditorium_type: { type: Sequelize.STRING, allowNull: false, primaryKey: true },
      auditorium_type_name: { type: Sequelize.STRING, allowNull: false }
    },
    { sequelize: seq, modelName: 'Auditorium_type', tableName: 'Auditorium_type', timestamps: false }
  );

  Auditorium.init(
    {
      auditorium: { type: Sequelize.STRING, allowNull: false, primaryKey: true },
      auditorium_name: { type: Sequelize.STRING, allowNull: false },
      auditorium_capacity: { type: Sequelize.INTEGER, allowNull: false },
      auditorium_type: { type: Sequelize.STRING, allowNull: false, references: { model: Auditorium_type, key: 'auditorium_type' } }
    },
    { sequelize: seq, modelName: 'Auditorium', tableName: 'Auditorium', timestamps: false }
  );
}

module.exports.ORM = (s) => { ORMhelper(s); return { Faculty, Pulpit, Teacher, Subject, Auditorium_type, Auditorium }; };