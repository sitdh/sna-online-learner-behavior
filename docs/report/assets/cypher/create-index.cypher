CREATE CONSTRAINT unique_course_id ON (c:Course) ASSERT c.course_id IS UNIQUE;
CREATE CONSTRAINT unique_learner_id ON (l:Learner) ASSERT l.learner_id IS UNIQUE;
CREATE CONSTRAINT unique_enrollment_id ON (e:Enrollment) ASSERT e.enrollment_id IS UNIQUE;
CREATE CONSTRAINT unique_course_module_id ON (m:Module) ASSERT m.module_id IS UNIQUE;
CREATE CONSTRAINT unique_module_object_id ON (o:ModuleObject) ASSERT o.object_id IS UNIQUE;